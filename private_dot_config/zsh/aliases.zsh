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

#alias v="$EDITOR"
#alias vi="$EDITOR"
#alias vim="$EDITOR"
#alias nvim="$EDITOR"

#if [[ "$EDITOR" == nvim ]]; then
#  alias vimdiff='nvim -d'
#fi

alias ,,='cd ..'
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

# Eza
alias l="eza -l --icons --git -a"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2  --icons --git"

# K8S
alias k="kubectl"
alias ka="kubectl apply -f"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdel="kubectl delete"
alias kl="kubectl logs"
alias kgpo="kubectl get pod"
alias kgd="kubectl get deployments"
alias kc="kubectx"
alias kns="kubens"
alias kl="kubectl logs -f"
alias ke="kubectl exec -it"
alias kcns='kubectl config set-context --current --namespace'

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

