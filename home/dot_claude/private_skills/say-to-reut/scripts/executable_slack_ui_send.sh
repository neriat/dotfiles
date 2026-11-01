#!/usr/bin/env bash
# Speak a (pre-translated) message with macOS `say` and send it to Reut Beldoch
# by driving the installed Slack desktop app: the .m4a is put on the clipboard,
# the DM is opened with the quick switcher (Cmd+K), the file is pasted into the
# composer, and Enter sends it. No Slack token is needed.
#
# Usage:
#   slack_ui_send.sh --lang <ru|zh|he|en|...> --text-file <path>
#                    [--voice <name>] [--no-send]
#
# --no-send stops after the clip is attached in the composer (nothing is sent).
# Requires Accessibility permission for the terminal app running this script
# (System Settings > Privacy & Security > Accessibility).
set -euo pipefail

RECIPIENT="Reut Beldoch"
STATE_DIR="$HOME/.cache/say-to-reut"

lang="" text_file="" voice="" no_send=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang) lang="$2"; shift 2 ;;
    --text-file) text_file="$2"; shift 2 ;;
    --voice) voice="$2"; shift 2 ;;
    --no-send) no_send=1; shift ;;
    *) echo "error: unknown argument $1" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
[[ -n "$lang" ]] || die "--lang is required"
[[ -s "$text_file" ]] || die "--text-file is missing or empty"

pick_voice() {
  local prefix="$1" preferred
  case "$prefix" in
    ru) preferred="Milena" ;;
    he) preferred="Carmit" ;;
    en) preferred="Samantha" ;;
    zh) preferred="Tingting" ;;
    *) preferred="" ;;
  esac
  # `say -v '?'` lines: "<name> <ll_CC>    # sample". Names may contain spaces/parens.
  say -v '?' | sed -E 's/[[:space:]]+#.*$//' \
    | sed -nE "s/^(.*[^[:space:]])[[:space:]]+(${prefix}_[A-Z]{2})$/\1/p" \
    | awk -v p="$preferred" 'NR==1{first=$0} p!="" && index($0,p)==1{print; found=1; exit} END{if(!found && first!="") print first}'
}

if [[ -z "$voice" ]]; then
  voice="$(pick_voice "$lang")"
  [[ -n "$voice" ]] || die "no installed 'say' voice for language '$lang'"
fi

# The file must outlive this script: Slack reads it when the paste lands.
mkdir -p "$STATE_DIR"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
m4a="$STATE_DIR/voice-note-$(date +%Y%m%d-%H%M%S).m4a"
say -v "$voice" -f "$text_file" -o "$workdir/clip.aiff"
afconvert -f m4af -d aac "$workdir/clip.aiff" "$m4a"
duration="$(afinfo "$m4a" | awk '/estimated duration/{print $3}')"
# Keep only the last few clips around.
ls -t "$STATE_DIR"/voice-note-*.m4a 2>/dev/null | tail -n +6 | xargs -r rm -f

osascript - "$m4a" "$RECIPIENT" "$no_send" <<'APPLESCRIPT'
on run argv
  set clipPath to item 1 of argv
  set recipient to item 2 of argv
  set noSend to (item 3 of argv) is "1"
  -- Use key codes and the clipboard, never `keystroke "<text>"`: keystroke goes
  -- through the active input source, so a Hebrew/Russian layout turns typed
  -- text and Cmd+<letter> shortcuts into garbage.
  tell application "Slack" to activate
  delay 1.0
  tell application "System Events"
    tell process "Slack"
      set frontmost to true
      key code 53 -- Escape: close any open popup or thread focus
      delay 0.3
      key code 40 using command down -- Cmd+K: quick switcher
      delay 0.8
      set the clipboard to recipient
      key code 9 using command down -- Cmd+V: paste the name
      delay 1.5
      key code 36 -- Return: open the top match
      delay 1.5
      set winName to name of front window
      if winName does not start with (recipient & " (DM)") then
        key code 53
        error "Slack did not open the DM with " & recipient & " (front window: " & winName & "). Nothing was sent."
      end if
    end tell
  end tell
  -- Set the file clipboard outside System Events and give Slack time to settle
  -- after the switch; a paste fired too early is silently dropped.
  set the clipboard to (POSIX file clipPath)
  delay 1.0
  tell application "System Events"
    tell process "Slack"
      key code 9 using command down -- Cmd+V: attach the clip
      delay 2.5
      if not noSend then
        key code 36 -- Return: send the message with the attached clip
        delay 1.0
      end if
    end tell
  end tell
end run
APPLESCRIPT

if [[ $no_send -eq 1 ]]; then
  echo "staged (not sent): voice=\"$voice\" duration=${duration}s file=$m4a"
else
  echo "sent via Slack app: voice=\"$voice\" duration=${duration}s file=$m4a"
fi
