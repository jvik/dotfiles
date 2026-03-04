#!/bin/bash
# Apply a sway layout and notify with the resulting container layout.
# Usage: layout.sh <layout args...>
# Example: layout.sh tabbed
#          layout.sh toggle split

swaymsg "layout $*"

sleep 0.05

layout=$(swaymsg -t get_tree | jq -r '
    recurse(.nodes[]?, .floating_nodes[]?) |
    select(.nodes[]?.focused? == true) |
    .layout
' | head -n1)

notify-send \
    -t 1800 \
    -h string:x-canonical-private-synchronous:sway-layout \
    "Layout: ${layout:-?}"
