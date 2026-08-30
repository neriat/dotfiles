# fpath / PATH assembly.
#
# Every fpath entry must be added HERE, before 10-omz.zsh sources oh-my-zsh --
# oh-my-zsh runs the one and only compinit. Do not call compinit anywhere else.

# OpenSpec shell completions
[[ -d "$HOME/.oh-my-zsh/custom/completions" ]] && \
  fpath=("$HOME/.oh-my-zsh/custom/completions" $fpath)

# Homebrew site-functions (eza, gh, ... auto-completions)
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
fi

# Docker CLI completions
[[ -d "$HOME/.docker/completions" ]] && \
  fpath=("$HOME/.docker/completions" $fpath)

# Locally-dropped completion functions (poetry, uv, ...)
[[ -d "$HOME/.zfunc" ]] && fpath+=("$HOME/.zfunc")

# --- PATH ---
# Solana (was exported three times across .zshrc/.zprofile; once is enough)
[[ -d "$HOME/.local/share/solana/install/active_release/bin" ]] && \
  export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

export PATH="$PATH:$HOME/.local/bin"   # pipx-style user bins, cursor-session CLI
export PATH="$PATH:$HOME/go/bin"       # `go install` targets
