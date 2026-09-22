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

# One -i per head, so each output locks to the image it already shows. Reusing
# the picker keeps the aspect-ratio bucketing in one place; if it prints
# nothing (no images installed), swaylock falls back to -c.
set --
while IFS="$(printf '\t')" read -r out path; do
    [ -n "$out" ] && [ -n "$path" ] || continue
    set -- "$@" -i "$out:$path"
done <<EOF
$("$SCRIPTS/set-wallpaper.sh" --print 2>/dev/null)
EOF

swaylock -c 444444 "$@"

kill "$blanker" 2>/dev/null
wait "$blanker" 2>/dev/null

exec "$SCRIPTS/restore-outputs.sh"
