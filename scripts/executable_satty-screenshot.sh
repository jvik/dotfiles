#!/usr/bin/env bash
# Capture with grim and hand the image to satty (Flatpak) for annotation.
# Usage: satty-screenshot.sh [region|full|window]
set -euo pipefail

mkdir -p "$HOME/Pictures"
tmpfile=$(mktemp "$HOME/Pictures/.satty-capture-XXXXXX.png")

# "<con_id> <fullscreen_mode>" lines for containers we un-fullscreened below.
restore_fs=""

cleanup() {
    pkill -x wayfreeze || true
    rm -f "$tmpfile"
    while read -r id mode; do
        [ -n "$id" ] || continue
        if [ "$mode" = "2" ]; then
            swaymsg "[con_id=$id] fullscreen enable global" >/dev/null || true
        else
            swaymsg "[con_id=$id] fullscreen enable" >/dev/null || true
        fi
    done <<<"$restore_fs"
}
trap cleanup EXIT

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

# Satty is a plain xdg-toplevel, so sway renders it *behind* a fullscreen window
# (only layer-shell overlays -- wayfreeze, slurp -- get drawn on top). Drop
# fullscreen on the focused workspace while satty is open; cleanup() restores it.
# The capture is already on disk, so the reflow can't affect the image.
ws_id=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .id')
restore_fs=$(swaymsg -t get_tree | jq -r --argjson ws "$ws_id" '
    .. | objects | select(.type == "workspace" and .id == $ws)
    | [recurse(.nodes[]?, .floating_nodes[]?)] | .[]
    | select((.fullscreen_mode // 0) > 0)
    | "\(.id) \(.fullscreen_mode)"')

while read -r id _; do
    [ -n "$id" ] || continue
    swaymsg "[con_id=$id] fullscreen disable" >/dev/null || true
done <<<"$restore_fs"

flatpak run org.satty.Satty \
    --filename "$tmpfile" \
    --output-filename "$HOME/Pictures/satty-%Y%m%d-%H%M%S.png" \
    --actions-on-enter save-to-clipboard \
    --copy-command "flatpak-spawn --host wl-copy --type image/png"
