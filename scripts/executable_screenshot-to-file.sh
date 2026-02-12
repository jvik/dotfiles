#!/usr/bin/env bash
# Save a selected region screenshot to ~/Pictures with timestamp

outdir="$HOME/Pictures"
mkdir -p "$outdir"
outfile="$outdir/screenshot-$(date +%Y%m%d-%H%M%S).png"

# Use slurp for region, grim for screenshot
region=$(slurp)
[ -z "$region" ] && exit 1

grim -g "$region" "$outfile"

# Prefer swaync-client for notification if available, else fallback to notify-send
if command -v swaync-client >/dev/null 2>&1; then
	swaync-client -s -t info -a screenshot "Screenshot saved" "Saved to: $outfile"
else
	notify-send "Screenshot saved" "Saved to: $outfile"
fi