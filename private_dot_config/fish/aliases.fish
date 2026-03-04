# Fish aliases (for commands that shouldn't expand like abbreviations)

# Screen with unicode support
alias screen='screen -U'

# Tmux with custom config
alias tmux="tmux -2 -f '$XDG_CONFIG_HOME/tmux/tmux.conf'"

# Update arkenfox user.js for Firefox
alias arkenfox-update='~/.config/mozilla/firefox/main/updater.sh'
