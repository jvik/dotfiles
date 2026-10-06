#!/usr/bin/env sh

APP_ID="waybar-battery"

if swaymsg -t get_tree | grep -q "\"app_id\": \"$APP_ID\""; then
    swaymsg "[app_id=$APP_ID] kill"
else
    flatpak run org.wezfurlong.wezterm \
        --config 'initial_rows = 30' --config 'initial_cols = 80' \
        start --class "$APP_ID" \
        -- bash "$HOME/.config/waybar/scripts/battery-view.sh"
fi
