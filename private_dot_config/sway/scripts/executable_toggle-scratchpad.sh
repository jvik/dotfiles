#!/bin/bash
# Usage: toggle-scratchpad.sh <app_id> <launch-command...>
app_id="$1"
shift

in_scratchpad=$(swaymsg -t get_tree | jq -r "
  first(
    .. | objects | select(.name? == \"__i3_scratch\") |
    .floating_nodes[]?, .nodes[]? |
    select(.app_id? == \"$app_id\")
  ) | .id // empty
" 2>/dev/null)

on_workspace=$(swaymsg -t get_tree | jq -r "
  first(
    .. | objects |
    select(.type? == \"workspace\") |
    recurse(.nodes[]?, .floating_nodes[]?) |
    select(.app_id? == \"$app_id\")
  ) | .id // empty
" 2>/dev/null)

if [ -n "$in_scratchpad" ]; then
    swaymsg "[app_id=\"$app_id\"] scratchpad show, floating disable"
elif [ -n "$on_workspace" ]; then
    swaymsg "[app_id=\"$app_id\"] move scratchpad"
else
    "$@" &
fi
