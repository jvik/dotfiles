#!/usr/bin/env bash
# Pick and apply a wallpaper per output, by aspect ratio and darkman mode.
#
#   (no args)      apply to every active output via swaymsg
#   --print        emit "<output>\t<path>" instead of applying (lockman.sh)
#   --mode MODE    force dark|light instead of asking darkman
#
# One image cannot serve this hardware: the office desks are 32:9 (5120x1440,
# 3840x1080), home is 21:9 (3840x1600) and the laptop panel is 16:10
# (1920x1200). sway's `fill` covers the output and crops the remainder, so a
# 16:9 source loses the vertical middle 50% on an ultrawide. Images are
# therefore bucketed by aspect ratio and chosen per output at runtime.
#
# Selection keys on the runtime name from get_outputs, not on the
# "Make Model Serial" identifiers kanshi uses, so a new desk needs no entry
# here -- the aspect ratio is the only thing that matters.

set -uo pipefail

ROOT=${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}

log() { printf 'set-wallpaper: %s\n' "$*" >&2; }

mode=
print_only=0

while [ $# -gt 0 ]; do
    case "$1" in
    --print) print_only=1 ;;
    --mode)
        shift
        mode=${1:-}
        ;;
    --mode=*) mode=${1#--mode=} ;;
    *)
        echo "usage: ${0##*/} [--print] [--mode dark|light]" >&2
        exit 2
        ;;
    esac
    shift
done

if [ -z "$mode" ] && command -v darkman >/dev/null; then
    # "null" when darkman has no location yet; the case below catches it.
    mode=$(darkman get 2>/dev/null)
fi
case "$mode" in
dark | light) ;;
*) mode=dark ;;
esac

case "$mode" in
dark) fallback_color='#282828' ;;  # gruvbox dark0, matching sway/colors/gruvbox
light) fallback_color='#fbf1c7' ;; # gruvbox light0
esac

# Called from a darkman hook and from a systemd user unit, neither of which
# necessarily inherits sway's env. Same discovery as on-output-change.sh.
if [ -z "${SWAYSOCK:-}" ]; then
    SWAYSOCK=$(find "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" -maxdepth 1 \
        -name 'sway-ipc.*.sock' -printf '%T@ %p\n' 2>/dev/null |
        sort -rn | head -1 | cut -d' ' -f2-)
    export SWAYSOCK
fi

# Aspect ratio scaled by 100, so this needs no bc/awk. Ratio is invariant under
# scale and correct under rotation when taken from .rect, which is why .rect is
# preferred over .current_mode below.
bucket_for() {
    local w=$1 h=$2 ratio
    [ "${h:-0}" -gt 0 ] 2>/dev/null || {
        echo standard
        return
    }
    ratio=$((w * 100 / h))
    if [ "$ratio" -ge 300 ]; then
        echo ultrawide
    elif [ "$ratio" -ge 200 ]; then
        echo wide
    else
        echo standard
    fi
}

list_images() {
    find "$1" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        2>/dev/null | sort
}

# The bucket directory or nothing -- deliberately no fall back to another
# bucket. A 16:10 image on a 32:9 output is cropped by more than half, which is
# the exact failure this whole arrangement exists to avoid; the solid colour
# below is the honest answer when a bucket is empty. generate-wallpapers.sh
# fills every bucket, so in practice this always finds something.
#
# Deterministic, so a hotplug or a DPMS wake never reshuffles the desktop, and
# two heads of the same bucket do not land on the same image.
pick_for() {
    local name=$1 bucket=$2 images count idx
    images=$(list_images "$ROOT/$mode/$bucket")
    [ -n "$images" ] || return 1
    count=$(printf '%s\n' "$images" | wc -l)
    idx=$(($(printf '%s' "$name" | cksum | cut -d' ' -f1) % count + 1))
    printf '%s\n' "$images" | sed -n "${idx}p"
}

outputs=$(swaymsg -t get_outputs -r 2>/dev/null |
    jq -r '.[] | select(.active) |
        [ .name,
          (if (.rect.width  // 0) > 0 then .rect.width  else (.current_mode.width  // 0) end),
          (if (.rect.height // 0) > 0 then .rect.height else (.current_mode.height // 0) end)
        ] | @tsv' 2>/dev/null)

if [ -z "$outputs" ]; then
    log "no active outputs (is sway running?)"
    exit 0
fi

rc=0
while IFS=$'\t' read -r name w h; do
    [ -n "$name" ] || continue
    bucket=$(bucket_for "$w" "$h")

    if path=$(pick_for "$name" "$bucket"); then
        if [ "$print_only" -eq 1 ]; then
            printf '%s\t%s\n' "$name" "$path"
        else
            swaymsg -q output "$name" bg "$path" fill || rc=1
        fi
        continue
    fi

    # Nothing to show: a solid gruvbox field beats a black desktop.
    log "no image for $name (${w}x${h}, $bucket, $mode); using $fallback_color"
    [ "$print_only" -eq 1 ] ||
        swaymsg -q output "$name" bg "$fallback_color" solid_color || rc=1
done <<EOF
$outputs
EOF

exit $rc
