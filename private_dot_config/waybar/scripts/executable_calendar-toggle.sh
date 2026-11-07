#!/usr/bin/env sh

APP_ID="waybar-calendar"

if swaymsg -t get_tree | grep -q "\"app_id\": \"$APP_ID\""; then
    swaymsg "[app_id=$APP_ID] kill"
else
    wezterm \
        --config 'initial_rows = 12' --config 'initial_cols = 28' \
        start --class "$APP_ID" \
        -- bash "$HOME/.config/waybar/scripts/calendar-view.sh"
fi
