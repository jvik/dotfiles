# Fish aliases (for commands that shouldn't expand like abbreviations)

# Screen with unicode support
alias screen='screen -U'

# Tmux with custom config
alias tmux="tmux -2 -f '$XDG_CONFIG_HOME/tmux/tmux.conf'"

# Launch Firefox with the correct profile
alias firefox='firefox --profile ~/.config/mozilla/firefox/main'

# Update arkenfox user.js for Firefox
# Commented out: shadows the function in functions/arkenfox-update.fish which passes -e -p flags
# alias arkenfox-update='~/.config/mozilla/firefox/main/updater.sh'
