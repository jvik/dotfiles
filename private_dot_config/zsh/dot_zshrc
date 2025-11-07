# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
source "$ZDOTDIR/env.zsh"
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/functions.zsh"

# Load oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh


if [[ -f "$ZDOTDIR/local.zsh" ]]; then
  source "$ZDOTDIR/local.zsh"
fi

if [[ "$(uname -s)" == 'Linux' ]]; then
  source "$ZDOTDIR/linux.zsh"
elif [[ "$(uname -s)" == 'Darwin' ]]; then
  source "$ZDOTDIR/mac.zsh"
fi

if [[ -e "$HOME/.zshrc_local" ]]; then
  source "$HOME/.zshrc_local"
fi

fvim() {
    local file
    file=$(fzf) && nvim "$file"
}

