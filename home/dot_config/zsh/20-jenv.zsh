# jenv, without the per-prompt fork.
#
# What this replaces, and why:
#   `eval "$(jenv init -)"` cost ~290ms every startup -- it eagerly runs
#   `jenv rehash` (~100ms) and `jenv refresh-plugins` (~163ms). Worse, jenv's
#   `export` plugin installed _jenv_export_hook into precmd_functions, forking
#   `jenv javahome` (~140ms) before EVERY prompt, to recompute a value that
#   only changes when you cd into a tree containing a .java-version file.
#
# Both are reimplemented below in pure zsh. Preserved behaviour:
#   - java/javac/... still resolve through ~/.jenv/shims
#   - JAVA_HOME / JDK_HOME still track .java-version per directory
#   - `jenv shell|local|global|rehash|...` all work and refresh JAVA_HOME
#
# Runs at step 2 (before ~/.devrc), so the shims prepend must stay ahead of
# every other JDK bin dir on PATH -- do not re-add openjdk@* to PATH in .devrc.

export JENV_ROOT="${JENV_ROOT:-$HOME/.jenv}"
path=("$JENV_ROOT/shims" "$JENV_ROOT/bin" $path)

# What `jenv version-name` resolves, without the fork: $JENV_VERSION, else the
# nearest .java-version walking up from $PWD, else the global version file.
_jenv_resolve_javahome() {
  emulate -L zsh          # also drops the `set -a` inherited from ~/.devrc
  local dir=$PWD name

  if [[ -n $JENV_VERSION ]]; then
    name=$JENV_VERSION
  else
    while [[ -n $dir ]]; do
      [[ -r $dir/.java-version ]] && { name=$(<$dir/.java-version); break }
      dir=${dir%/*}
    done
    [[ -z $name && -r $JENV_ROOT/version ]] && name=$(<$JENV_ROOT/version)
  fi
  name=${name//[[:space:]]/}

  [[ -n $name && -d $JENV_ROOT/versions/$name ]] || return 0

  export JAVA_HOME="$JENV_ROOT/versions/$name"
  export JENV_FORCEJAVAHOME=true
  if [[ -x $JAVA_HOME/bin/javac ]]; then
    export JDK_HOME="$JAVA_HOME"
    export JENV_FORCEJDKHOME=true
  fi
}

# chpwd, not precmd: re-resolve only when the directory actually changes.
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _jenv_resolve_javahome
_jenv_resolve_javahome

# Mirrors the dispatcher `jenv init -` would have defined, minus the eager
# rehash/refresh-plugins. Costs nothing until you actually invoke `jenv`.
jenv() {
  case "$1" in
    enable-plugin|rehash|shell|shell-options)
      eval "$(command jenv "sh-$1" "${@:2}")" ;;
    *)
      command jenv "$@" ;;
  esac
  local ret=$?
  _jenv_resolve_javahome
  return $ret
}

# compctl-based, no compinit dependency, ~0ms.
[[ -r /opt/homebrew/opt/jenv/libexec/completions/jenv.zsh ]] && \
  source /opt/homebrew/opt/jenv/libexec/completions/jenv.zsh
