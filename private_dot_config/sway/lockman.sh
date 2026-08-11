#!/bin/sh
# Lock now, blank the outputs shortly after, restore them on unlock.
#
# This swayidle is private to the lock session (it is what gives wake-on-input
# while locked) and is killed by PID on unlock. The global daemon
# scripts/idle.sh is PID-file scoped, so neither instance kills the other.

set -u
SCRIPTS="$HOME/.config/sway/scripts"

swayidle \
    timeout 10 'swaymsg "output * power off"' \
    resume "$SCRIPTS/restore-outputs.sh" &
blanker=$!

swaylock -c 444444

kill "$blanker" 2>/dev/null
wait "$blanker" 2>/dev/null

exec "$SCRIPTS/restore-outputs.sh"
