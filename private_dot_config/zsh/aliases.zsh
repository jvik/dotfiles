alias ..='cd ..'
alias 2..='cd ../..'
alias 3..='cd ../../..'
alias 4..='cd ../../../..'
alias 5..='cd ../../../../..'

alias reload-zsh='source $ZDOTDIR/.zshrc'

alias q='exit'

alias screen='screen -U'
alias tmux="tmux -2 -f '$XDG_CONFIG_HOME/tmux/tmux.conf'"
alias tmuxa='tmux attach || tmux new-session'

alias v="$EDITOR"
alias vi="$EDITOR"
alias vim="$EDITOR"
alias nvim="$EDITOR"

if [[ "$EDITOR" == nvim ]]; then
  alias vimdiff='nvim -d'
fi

alias ,,='cd ..'
alias ..l='cd .. && ls'
alias :q='exit'
alias cd..='cd ..'
alias mdkir='mkdir'
alias dc='cd'
alias sl='ls'
alias sudp='sudo'

alias k="kubectl"
alias i3config="nvim ~/.config/i3/config"
alias audio="alsamixer"

alias bw="flatpak run --command=bw com.bitwarden.desktop"

mkcd () {
  \mkdir -p "$1"
  cd "$1"
}

tempe () {
  cd "$(mktemp -d)"
  chmod -R 0700 .
  if [[ $# -eq 1 ]]; then
    \mkdir -p "$1"
    cd "$1"
    chmod -R 0700 .
  fi
}

git-fworktree () {
  cd "$(git worktree list | fzf | awk '{print $1}')"
}

