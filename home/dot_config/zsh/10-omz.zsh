# oh-my-zsh. Sourcing it runs the single compinit for the session, so all
# fpath mutation must already have happened in 00-path.zsh.

export DEFAULT_USER="$(whoami)"
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  zsh-syntax-highlighting
  you-should-use
  zsh-bat
  zsh-autosuggestions
  zsh-eza
  fzf
  poetry
  docker
  direnv
)

source "$ZSH/oh-my-zsh.sh"
