#!/bin/bash
# Check for pending dnf/apt/flatpak updates and notify when the count changes.
# Designed to run as a systemd timer (default mode). `--status` prints cached
# waybar JSON without touching the network, for waybar's exec polling.

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/update-check"
mkdir -p "$STATE_DIR"

if [[ "${1:-}" == "--status" ]]; then
    count=$(cat "$STATE_DIR/count" 2>/dev/null || echo 0)
    if (( count > 0 )); then
        class=pending
        tooltip="$count updates available — click to run sysup"
    else
        class=idle
        tooltip="No updates pending"
    fi
    printf '{"text": "%d 󰚰", "class": "%s", "tooltip": "%s"}\n' "$count" "$class" "$tooltip"
    exit 0
fi

if command -v dnf &>/dev/null; then
    pkg_count=$(dnf check-update -q 2>/dev/null | grep -c '^\S')
elif command -v apt &>/dev/null; then
    # apt-get's summary line already excludes packages apt would hold back
    # due to unresolved dependency changes — unlike `apt list --upgradable`,
    # which counts any newer candidate regardless of whether apt will touch it.
    summary=$(apt-get dist-upgrade --dry-run 2>/dev/null)
    upgraded=$(grep -oP '^\d+(?= upgraded)' <<< "$summary")
    installed=$(grep -oP '(?<=, )\d+(?= newly installed)' <<< "$summary")
    pkg_count=$(( ${upgraded:-0} + ${installed:-0} ))
else
    pkg_count=0
fi
flatpak_count=$(flatpak list --updates 2>/dev/null | grep -c '^\S')
count=$(( pkg_count + flatpak_count ))
echo "$count" > "$STATE_DIR/count"

# Nudge waybar to re-run the module's exec now instead of waiting for its
# polling interval (see custom/update's "signal" in waybar/config.tmpl).
pkill -RTMIN+8 waybar 2>/dev/null

notified_file="$STATE_DIR/notified"
prev_notified=0
[[ -f "$notified_file" ]] && prev_notified=$(cat "$notified_file")

if (( count > 0 )); then
    if (( count != prev_notified )); then
        notify-send -i software-update-available \
            "Updates available" "$count package(s) pending — run sysup"
        echo "$count" > "$notified_file"
    fi
else
    rm -f "$notified_file"
fi
