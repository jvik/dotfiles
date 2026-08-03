#!/usr/bin/env bash
# Capture with grim and hand the image to satty (Flatpak) for annotation.
# Usage: satty-screenshot.sh [region|full|window]
set -euo pipefail

mkdir -p "$HOME/Pictures"
tmpfile=$(mktemp "$HOME/Pictures/.satty-capture-XXXXXX.png")
trap 'pkill -x wayfreeze || true; rm -f "$tmpfile"' EXIT

case "${1:-region}" in
    region)
        geometry=$(slurp) || exit 0 # slurp cancelled
        ;;
    full)
        geometry=""
        output=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
        ;;
    window)
        geometry=$(swaymsg -t get_tree |
            jq -r '.. | select(.focused? == true) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')
        ;;
    *)
        echo "usage: ${0##*/} [region|full|window]" >&2
        exit 1
        ;;
esac

if [ -n "$geometry" ]; then
    grim_args=(-g "$geometry")
else
    grim_args=(-o "$output")
fi

# Capture to a file (rather than piping straight into satty) so wayfreeze can
# be killed the moment the capture finishes, before satty opens -- otherwise
# the frozen overlay stays on top of satty's window until the next click
# dismisses it.
grim "${grim_args[@]}" "$tmpfile"
pkill -x wayfreeze || true

flatpak run org.satty.Satty \
    --filename "$tmpfile" \
    --output-filename "$HOME/Pictures/satty-%Y%m%d-%H%M%S.png" \
    --actions-on-enter save-to-clipboard \
    --copy-command "flatpak-spawn --host wl-copy --type image/png"
