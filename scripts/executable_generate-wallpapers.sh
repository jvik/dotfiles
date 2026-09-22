#!/usr/bin/env bash
# Generate the wallpaper set for set-wallpaper.sh.
#
#   ~/Pictures/wallpapers/<dark|light>/<standard|wide|ultrawide>/
#
# Everything here is generated, not downloaded: one image per preset per
# aspect-ratio bucket, at that bucket's native resolution. That is the whole
# point -- a generated gradient is an exact fit at 5120x1440 and at 1920x1200
# alike, so nothing is ever cropped, and there is no source repo to curate.
#
# The palette COMPLEMENTS gruvbox rather than reproducing it. Filling the
# desktop with the same warm ochres as the chrome makes the whole screen one
# muddy yellow-brown; these sit on the cool side (teal, indigo, plum, slate)
# so the warm #ebdbb2 text and #fabd2f accents read as accents against them.
# Dark presets stay dark enough to sit behind windows; light presets stay pale
# enough for #fbf1c7 chrome while keeping real hue travel, so they do not
# collapse into flat white.
#
# Idempotent: an existing file is never rewritten. FORCE=1 regenerates.

set -euo pipefail

ROOT=${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}

# Light ramps need less dithering than dark ones: banding is far less visible
# at the top of the tonal range.
NOISE_DARK=0.04
NOISE_LIGHT=0.03

log() { printf 'generate-wallpapers: %s\n' "$*" >&2; }

if command -v magick >/dev/null; then
    IM=(magick)
elif command -v convert >/dev/null; then
    IM=(convert) # ImageMagick 6
else
    log "ImageMagick not found; install it (dnf install ImageMagick)"
    exit 1
fi

# bucket:WxH -- one resolution per bucket. Within a bucket every output has the
# same aspect ratio, so a single image covers all of them with zero crop; the
# 3840x1080 and 5120x1440 ultrawides are both exactly 32:9.
BUCKETS=(
    "ultrawide:5120x1440"
    "wide:3840x1600"
    "standard:1920x1200"
)

# name:mode:topleft:topright:bottomleft:bottomright
PRESETS=(
    "abyss:dark:#16323a:#241f3d:#0d1f26:#1b3a3a"
    "nocturne:dark:#2b1f3a:#15303f:#1d1b2e:#26384a"
    "tide:dark:#0f2b2b:#1b2f4a:#0b1d22:#123a38"
    "ultra:dark:#1a1338:#123043:#0d0f24:#1d4348"
    "moss:dark:#13291f:#16323a:#0c1a14:#1d3b33"
    "haze:light:#dbe6ee:#e2dcee:#cfe0e4:#e6dfec"
    "mist:light:#cfe0ea:#dcd9ee:#c4d9e0:#e0dbe8"
    "glacier:light:#c8dce8:#d6d6ea:#bcd4dd:#dcd8e6"
    "bloom:light:#d9e3f0:#ece0e8:#c9dbe6:#e6dcea"
)

# A four-corner bilinear mesh, not a two-stop ramp: the colour travels across
# the frame instead of banding in one direction, which is what stops a 5120px
# background reading as a flat field.
#
# The faint Gaussian noise dithers it. These ramps span ~20 8-bit levels, so
# over 1440 rows they band in visible steps without it; it survives q92 as a
# fraction of a level, enough to break the edges and invisible as grain.
#
# JPEG, deliberately: at 5120x1440 this is ~200KB and 0.3s, against 6.2MB and
# 12s for the same image as 8-bit PNG (32MB at PNG's default 16-bit depth).
# Noise is incompressible, so a lossless container is the wrong choice for it.
generate() {
    local out=$1 size=$2 tl=$3 tr=$4 bl=$5 br=$6 noise=$7
    local w=${size%x*} h=${size#*x}
    local x=$((w - 1)) y=$((h - 1))

    "${IM[@]}" -size "$size" xc: -sparse-color bilinear \
        "0,0 $tl $x,0 $tr 0,$y $bl $x,$y $br" \
        -attenuate "$noise" +noise Gaussian \
        -quality 92 "$out"
}

made=0
kept=0

for bucket_entry in "${BUCKETS[@]}"; do
    bucket=${bucket_entry%%:*}
    size=${bucket_entry#*:}

    for preset in "${PRESETS[@]}"; do
        IFS=: read -r name mode tl tr bl br <<<"$preset"

        dir=$ROOT/$mode/$bucket
        mkdir -p "$dir"
        out=$dir/$name-$size.jpg

        if [ -e "$out" ] && [ "${FORCE:-0}" != 1 ]; then
            kept=$((kept + 1))
            continue
        fi

        if [ "$mode" = dark ]; then
            noise=$NOISE_DARK
        else
            noise=$NOISE_LIGHT
        fi

        generate "$out" "$size" "$tl" "$tr" "$bl" "$br" "$noise"
        log "generated ${out#"$ROOT"/}"
        made=$((made + 1))
    done
done

log "$made generated, $kept already present (FORCE=1 to regenerate)"
log "done; run ~/.config/sway/scripts/set-wallpaper.sh to apply"
