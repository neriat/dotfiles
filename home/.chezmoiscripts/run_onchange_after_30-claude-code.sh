#!/bin/sh
# Claude Code CLI, via its official installer (works on macOS and Linux).
# Deliberately not a Homebrew formula -- this is the method Anthropic documents.
#
# Install-if-missing only: Claude Code updates itself, so re-running the
# installer on every apply would fight its own updater.
set -eu

if command -v claude >/dev/null 2>&1 || [ -x "$HOME/.local/bin/claude" ]; then
    exit 0
fi

echo "==> Installing Claude Code CLI"
curl -fsSL https://claude.ai/install.sh | bash
