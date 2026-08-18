#!/bin/bash
# Usage: toggle-scratchpad.sh <app_id> <launch-command...>
app_id="$1"
shift

# Slack huddle windows and Slack/Teams share indicators reuse their parent
# app's app_id but have their own for_window rules keeping them floating,
# sticky, and positioned — exclude them here and dispatch via con_id below
# so the toggle only ever touches the actual main app window.
in_scratchpad=$(swaymsg -t get_tree | jq -r "
  first(
    .. | objects | select(.name? == \"__i3_scratch\") |
    .floating_nodes[]?, .nodes[]? |
    select(.app_id? == \"$app_id\") |
    select((.name? // \"\") | test(\"Huddle|Sharing Indicator|Screen is being shared\") | not)
  ) | .id // empty
" 2>/dev/null)

focused_ws=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .name')

on_current=$(swaymsg -t get_tree | jq -r "
  first(
    .. | objects |
    select(.type? == \"workspace\" and .name? == \"$focused_ws\") |
    recurse(.nodes[]?, .floating_nodes[]?) |
    select(.app_id? == \"$app_id\") |
    select((.name? // \"\") | test(\"Huddle|Sharing Indicator|Screen is being shared\") | not)
  ) | .id // empty
" 2>/dev/null)

on_workspace=$(swaymsg -t get_tree | jq -r "
  first(
    .. | objects |
    select(.type? == \"workspace\") |
    recurse(.nodes[]?, .floating_nodes[]?) |
    select(.app_id? == \"$app_id\") |
    select((.name? // \"\") | test(\"Huddle|Sharing Indicator|Screen is being shared\") | not)
  ) | .id // empty
" 2>/dev/null)

if [ -n "$in_scratchpad" ]; then
    swaymsg "[con_id=$in_scratchpad] scratchpad show, floating disable"
elif [ -n "$on_current" ]; then
    swaymsg "[con_id=$on_current] move scratchpad"
elif [ -n "$on_workspace" ]; then
    swaymsg "[con_id=$on_workspace] move container to workspace current, focus"
else
    "$@" &
fi
