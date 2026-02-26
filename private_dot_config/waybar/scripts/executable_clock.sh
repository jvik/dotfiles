#!/usr/bin/env sh

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-clock-show-date-until"
SHOW_DATE_SECONDS=5

now="$(date +%s)"

if [ "${1:-}" = "toggle-date" ]; then
    echo "$((now + SHOW_DATE_SECONDS))" > "$STATE_FILE"
    pkill -RTMIN+8 waybar >/dev/null 2>&1
    exit 0
fi

until_ts=0
if [ -f "$STATE_FILE" ]; then
    until_ts="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
fi

if [ "$until_ts" -gt "$now" ] 2>/dev/null; then
    date '+%Y-%m-%d'
else
    date '+%H:%M'
fi
