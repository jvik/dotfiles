if hash getconf 2>/dev/null; then
  PATH="$(getconf PATH)"
fi
prepend() {
  [ -d "$1" ] && PATH="$1:$PATH"
}
prepend '/usr/local/bin'
prepend '/opt/homebrew/bin'
prepend '/opt/homebrew/sbin'
prepend "$HOME/bin"
prepend "$HOME/go/bin"
prepend '/home/linuxbrew/.linuxbrew/bin'
prepend "$HOME/.local/bin"
prepend "$HOME/.cargo/bin"

if hash nvim 2>/dev/null; then
  export EDITOR=nvim
  export MANPAGER='nvim +Man!'
elif hash vim 2>/dev/null; then
  export EDITOR=vim
else
  export EDITOR=vi
fi
export USE_EDITOR="$EDITOR"
export VISUAL="$EDITOR"

export BROWSER=/usr/bin/firefox



export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# zsh stuff

#source "$HOME/.config/zsh/antigen.zsh"
#antigen use oh-my-zsh
#antigen bundle jeffreytse/zsh-vi-mode
# Load the theme.
#antigen theme robbyrussell

# Tell Antigen that you're done.
#antigen apply
ZSH_THEME="robbyrussell"

export HISTFILE="$XDG_CACHE_HOME/zsh_history"
export HISTSIZE=10000
export SAVEHIST=9000

export CLICOLOR=1

export ZLE_RPROMPT_INDENT=0

export SSH_AUTH_SOCK=$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock

plugins=(vi-mode git kubectl terraform azure)
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)

# Load other stuff

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
eval "$(zoxide init zsh)"
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
