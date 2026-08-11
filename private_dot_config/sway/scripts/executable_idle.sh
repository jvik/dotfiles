#!/bin/sh
# Global idle daemon for sway.
#
# Tracked by PID file so a sway reload replaces only this instance. The old
# `exec_always killall swayidle; swayidle -w ...` also killed the short-lived
# swayidle that lockman.sh runs while the screen is locked, which left the
# session with no idle handling at all.

set -u
SCRIPTS="$HOME/.config/sway/scripts"
PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/sway-idle.pid"

if [ -r "$PIDFILE" ]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
fi
echo $$ >"$PIDFILE"

set -- -w \
    timeout 300 'swaymsg "output * power off"' resume "$SCRIPTS/restore-outputs.sh" \
    timeout 360 'swaylock -f'

# Only arm suspend on battery-equipped hosts. The old sway config expanded to a
# degenerate `timeout 0 'systemctl suspend'` on desktops; those rely on the
# IdleAction=ignore logind drop-in from the bootstrap role instead.
if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    set -- "$@" timeout 600 'systemctl suspend'
fi

set -- "$@" before-sleep 'swaylock -f' lock 'swaylock -f'

# exec, so the PID recorded above is swayidle's own
exec swayidle "$@"
