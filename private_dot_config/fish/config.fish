# Fish Shell Configuration
# Main config file for Fish shell

# Source environment variables
source $HOME/.config/fish/env.fish

# Source abbreviations
source $HOME/.config/fish/abbr.fish

# Source aliases
source $HOME/.config/fish/aliases.fish

# Source key bindings
source $HOME/.config/fish/keybindings.fish

# Source functions are automatically loaded from functions/ directory

# Enable Vi mode
fish_vi_key_bindings


# Color scheme and syntax highlighting
set -g fish_color_normal normal
set -g fish_color_command blue
set -g fish_color_keyword magenta
set -g fish_color_quote yellow
set -g fish_color_redirection cyan
set -g fish_color_end green
set -g fish_color_error red --bold
set -g fish_color_param cyan
set -g fish_color_comment brblack
set -g fish_color_match --background=brblue --bold
set -g fish_color_selection white --bold --background=brblack
set -g fish_color_search_match bryellow --background=brblack
set -g fish_color_operator brcyan
set -g fish_color_escape brcyan
set -g fish_color_autosuggestion brblack

# Pager colors
set -g fish_pager_color_prefix cyan --bold --underline
set -g fish_pager_color_completion normal
set -g fish_pager_color_description yellow
set -g fish_pager_color_progress brwhite --background=cyan

# Disable greeting
set -g fish_greeting

# History
set -g fish_history_file $XDG_CACHE_HOME/fish_history

# Initialize tools
if type -q brew
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
end

if type -q zoxide
    zoxide init fish | source
end

# Load local config if it exists
if test -f $HOME/.config/fish/local.fish
    source $HOME/.config/fish/local.fish
end

# OS-specific configuration
if test (uname -s) = Linux
    source $HOME/.config/fish/linux.fish
else if test (uname -s) = Darwin
    source $HOME/.config/fish/mac.fish
end

# NVM configuration
if test -d $HOME/.nvm
    set -gx NVM_DIR $HOME/.nvm
end
