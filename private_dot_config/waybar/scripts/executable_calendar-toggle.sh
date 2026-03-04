#!/usr/bin/env sh

APP_ID="waybar-calendar"

if swaymsg -t get_tree | grep -q "\"app_id\": \"$APP_ID\""; then
    swaymsg "[app_id=$APP_ID] kill"
else
    wezterm start --class "$APP_ID" -- sh -c 'ncal -b -w -M; read -r done'
fi
