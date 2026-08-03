#!/usr/bin/env bash
# Capture with grim and hand the image to satty (Flatpak) for annotation.
# Usage: satty-screenshot.sh [region|full|window]
set -euo pipefail

mkdir -p "$HOME/Pictures"

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

# The Flatpak sandbox has a private /tmp, so the capture goes over stdin rather
# than through a temp file. ~/Pictures is writable via its filesystems=home perm.
grim "${grim_args[@]}" - | flatpak run org.satty.Satty \
    --filename - \
    --output-filename "$HOME/Pictures/satty-%Y%m%d-%H%M%S.png" \
    --early-exit all \
    --actions-on-enter save-to-clipboard
