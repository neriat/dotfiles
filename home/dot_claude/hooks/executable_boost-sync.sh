#!/usr/bin/env bash
BOOST_EXE="${HOME}/.local/bin/boost"
export PATH="$PATH:${HOME}/.local/bin"
# boost-hook-version: v0.13.3
# boost-skill-version: v0.13.3

_boost_find_jq() {
  if command -v jq &>/dev/null; then
    return 0
  fi
  for candidate in \
    "/c/ProgramData/chocolatey/bin/jq" \
    "/c/ProgramData/chocolatey/bin/jq.exe" \
    "/c/Program Files/Git/usr/bin/jq" \
    "/c/Program Files/Git/usr/bin/jq.exe"; do
    if [ -x "$candidate" ]; then
      export PATH="${PATH}:$(dirname "$candidate")"
      command -v jq &>/dev/null && return 0
    fi
  done
  return 1
}
_boost_resolve_exe() {
  if [ -n "${BOOST_EXE:-}" ] && [ -x "$BOOST_EXE" ]; then
    return 0
  fi
  local hook_dir=""
  if [ -n "${BASH_SOURCE[0]:-}" ]; then
    hook_dir=$(_boost_path_for_wrap "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")
  fi
  if [ -n "$hook_dir" ] && [ -x "$hook_dir/boost" ]; then
    BOOST_EXE="$hook_dir/boost"
    return 0
  fi
  if [ -n "${HOME:-}" ] && [ -x "${HOME}/.local/bin/boost" ]; then
    BOOST_EXE="${HOME}/.local/bin/boost"
    return 0
  fi
  if [ -n "${HOME:-}" ] && [ -x "${HOME}/.local/bin/boost.exe" ]; then
    BOOST_EXE="${HOME}/.local/bin/boost.exe"
    return 0
  fi
  if [ -n "${LOCALAPPDATA:-}" ]; then
  local win_boost="${LOCALAPPDATA}/boost/bin/boost.exe"
    if [ -x "$win_boost" ]; then
      BOOST_EXE="$win_boost"
      return 0
    fi
  fi
  BOOST_EXE=$(command -v boost 2>/dev/null || true)
  [ -n "$BOOST_EXE" ] && [ -x "$BOOST_EXE" ]
}
_boost_hook_env_keys="BOOST_DB_PATH BOOST_FEATURE_FLAGS_FORCE_ENABLED BOOST_OTEL_MIN_DURATION"
_boost_bash_sq() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
}
_boost_path_for_wrap() {
  local p="$1"
  case "${OSTYPE:-}" in
    msys*|cygwin*|win32*)
      printf '%s' "$p" | sed 's/\\/\//g'
      ;;
    *)
      printf '%s' "$p"
      ;;
  esac
}
# Detect a Windows host. The hook itself runs in bash (Git Bash) on Windows, but
# some agents (notably Codex) execute the rewritten command via powershell.exe,
# which cannot parse the POSIX wrapper — those hooks pick the PowerShell wrapper
# when this returns 0.
_boost_is_windows() {
  case "${OSTYPE:-}" in
    msys*|cygwin*|win32*) return 0 ;;
  esac
  case "${OS:-}" in
    Windows_NT) return 0 ;;
  esac
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
  esac
  return 1
}
_boost_wrap_body() {
  local body="$1"
  case "$body" in
    *'|'*|*'&&'*|*'||'*|*';'*|*'&'*)
      printf 'bash -lc %s' "'$(_boost_bash_sq "$body")'"
      ;;
    *)
      printf '%s' "$body"
      ;;
  esac
}
_boost_write_hook_meta_file() {
  local meta="$1"
  local dir="${TMPDIR:-/tmp}"
  local f
  f=$(mktemp "${dir}/boost-hook-meta.XXXXXX") || return 1
  printf '%s' "$meta" >"$f" || return 1
  printf '%s' "$f"
}
_boost_wrap_rewritten() {
  local meta_json="$1" body="$2"
  local meta_file meta_file_sq bindir bindir_q env_exports="" key val val_sq run_body
  meta_file=$(_boost_write_hook_meta_file "$meta_json")
  if [ -z "$meta_file" ]; then
    return 1
  fi
  meta_file_sq="'$(_boost_bash_sq "$meta_file")'"
  bindir=$(_boost_path_for_wrap "$(dirname "$BOOST_EXE")")
  bindir_q="'$(_boost_bash_sq "$bindir")'"
  for key in $_boost_hook_env_keys; do
    val="${!key:-}"
    if [ -n "$val" ]; then
      val=$(_boost_path_for_wrap "$val")
      val_sq="'$(_boost_bash_sq "$val")'"
      env_exports="${env_exports}export ${key}=${val_sq}; "
    fi
  done
  run_body=$(_boost_wrap_body "$body")
  printf '(%sexport BOOST_HOOK_META_FILE=%s; PATH=%s:${PATH:-}; %s)' \
    "$env_exports" "$meta_file_sq" "$bindir_q" "$run_body"
}
# Detached Stop-hook sync: forward gh auth + PATH (hooks often run with a minimal env).
_boost_run_detached_sync() {
  local hmeta="${1:-}"
  (
    [ -n "${HOME:-}" ] && export HOME
    [ -n "${USERPROFILE:-}" ] && export USERPROFILE
    [ -n "${PATH:-}" ] && export PATH
    [ -n "${BOOST_DB_PATH:-}" ] && export BOOST_DB_PATH
    [ -n "${BOOST_FEATURE_FLAGS_FORCE_ENABLED:-}" ] && export BOOST_FEATURE_FLAGS_FORCE_ENABLED
    [ -n "${BOOST_OTEL_MIN_DURATION:-}" ] && export BOOST_OTEL_MIN_DURATION
    [ -n "${GH_TOKEN:-}" ] && export GH_TOKEN
    [ -n "${GITHUB_TOKEN:-}" ] && export GITHUB_TOKEN
    [ -n "${GH_HOST:-}" ] && export GH_HOST
    [ -n "${XDG_CONFIG_HOME:-}" ] && export XDG_CONFIG_HOME
    [ -n "$hmeta" ] && export BOOST_HOOK_META="$hmeta"
    nohup "$BOOST_EXE" sync >/dev/null 2>&1 < /dev/null & disown
  ) >/dev/null 2>&1
}


# Boost agent-finished hook — ingests the session transcript then drains
# locally captured OpenTelemetry spans to the configured OTLP endpoint.
# Runs detached so the agent loop never waits on upload.
_boost_resolve_exe || exit 0
_boost_find_jq || true
INPUT=$(cat)
HMETA=$(echo "$INPUT" | jq -c '
  . as $in
  | ($in + {
      agent_type: (
        if ($in.agent_type // "") != "" then $in.agent_type
        elif ($in.conversation_id // "") != "" then "cursor"
        elif ($in.session_id // "") != "" then "claude_code"
        else "unknown"
        end
      ),
      transcript_path: ($in.transcript_path // $in.transcriptPath // ""),
      cwd: ($in.cwd // $in.workspace_roots[0] // "")
    })
' 2>/dev/null) || HMETA=""
_boost_run_detached_sync "$HMETA"
exit 0
