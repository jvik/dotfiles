# Environment variables for Fish shell

# XDG Base Directory
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_CACHE_HOME $HOME/.cache
set -gx XDG_DATA_HOME $HOME/.local/share

# Editor configuration
if type -q nvim
    set -gx EDITOR nvim
    set -gx MANPAGER 'nvim +Man!'
else if type -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end

set -gx USE_EDITOR $EDITOR
set -gx VISUAL $EDITOR

# Browser
set -gx BROWSER /usr/bin/firefox

# Enable colors
set -gx CLICOLOR 1

# History configuration
set -gx HISTSIZE 10000

# SSH Auth Socket
set -gx SSH_AUTH_SOCK $HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock

# PATH configuration
fish_add_path -p /usr/local/bin
fish_add_path -p /opt/homebrew/bin
fish_add_path -p /opt/homebrew/sbin
fish_add_path -p $HOME/bin
fish_add_path -p $HOME/go/bin
fish_add_path -p /home/linuxbrew/.linuxbrew/bin
fish_add_path -p $HOME/.local/bin
fish_add_path -p $HOME/.cargo/bin
fish_add_path -p /nix/var/nix/profiles/default/bin
