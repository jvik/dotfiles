# Linux-specific configuration

# XDG directories for Linux
set -gx XDG_DESKTOP_DIR $HOME/Desktop
set -gx XDG_DOCUMENTS_DIR $HOME/Documents
set -gx XDG_DOWNLOAD_DIR $HOME/Desktop
set -gx XDG_MUSIC_DIR $HOME/Music
set -gx XDG_PICTURES_DIR $HOME/Pictures
set -gx XDG_PUBLICSHARE_DIR $HOME/Public
set -gx XDG_VIDEOS_DIR $HOME/Videos

# Open files with default application
alias open='xdg-open'
