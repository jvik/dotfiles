#!/bin/sh
# Subscribe to sway output events and resize all tiling windows to fill their containers.
# This fixes windows not filling the full width after kanshi applies a profile.
swaymsg -t subscribe '["output"]' --monitor | while read -r _; do
    swaymsg "[tiling] resize set 0 0"
done
