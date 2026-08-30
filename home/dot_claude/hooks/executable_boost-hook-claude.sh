#!/usr/bin/env bash
BOOST_EXE="${HOME}/.local/bin/boost"
export PATH="$PATH:${HOME}/.local/bin"
# boost-hook-version: v0.13.3
# boost-skill-version: v0.13.3

if [ -z "${BOOST_EXE:-}" ] || [ ! -x "$BOOST_EXE" ]; then
  echo "[boost] WARNING: boost binary not found (install boost and run boost update to refresh hooks)." >&2
  exit 0
fi

_boost_out=$("$BOOST_EXE" hook claude 2>/dev/null) || exit 0
case "$_boost_out" in
  "") : ;;
  "{"*) printf '%s' "$_boost_out" ;;
  *) : ;;
esac
exit 0