#!/bin/bash
# Check battery levels across all devices (UPower + Solaar) and notify when low.
# Designed to run as a systemd timer. Uses state files to avoid repeated alerts.

THRESHOLD=15
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/battery-check"
mkdir -p "$STATE_DIR"

if [[ "${1:-}" == "--clear-state" ]]; then
    find "$STATE_DIR" -name '*.state' -delete 2>/dev/null
    rm -f "$STATE_DIR/.last_reset"
fi

# Reset state once per day so devices re-notify after recovering and dropping again
RESET_STAMP="$STATE_DIR/.last_reset"
if [[ ! -f "$RESET_STAMP" ]] || (( $(date +%s) - $(stat -c %Y "$RESET_STAMP") > 86400 )); then
    find "$STATE_DIR" -name '*.state' -delete 2>/dev/null
    touch "$RESET_STAMP"
fi

notify_if_low() {
    local device_id="$1"
    local device_name="$2"
    local level="$3"
    local state_file="$STATE_DIR/${device_id}.state"
    local prev_state="ok"

    [[ -f "$state_file" ]] && prev_state=$(cat "$state_file")

    if (( level < THRESHOLD )); then
        if [[ "$prev_state" != "low" ]]; then
            notify-send -u critical -i battery-caution \
                "Low Battery: $device_name" "Battery at ${level}%"
            echo "low" > "$state_file"
        fi
    else
        echo "ok" > "$state_file"
    fi
}

# --- Start Solaar in background while UPower runs ---
SOLAAR_TMP=$(mktemp)
if command -v solaar &>/dev/null; then
    solaar show >"$SOLAAR_TMP" 2>/dev/null &
    SOLAAR_PID=$!
fi

# --- UPower devices (Bluetooth HID, laptop, etc.) ---
while IFS= read -r device; do
    info=$(upower -i "$device")
    type=$(echo "$info" | awk '/^\s+type:/{print $2}')
    [[ "$type" != "battery" ]] && continue

    level=$(echo "$info" | grep -oP '(?<=percentage:\s{1,10})\d+')
    [[ -z "$level" ]] && continue

    name=$(echo "$info" | awk '/^\s+model:/{$1=""; sub(/^ /, ""); print}')
    [[ -z "$name" ]] && name=$(basename "$device")

    device_id=$(echo "$device" | tr -dc '[:alnum:]_-')
    notify_if_low "$device_id" "$name" "$level"
done < <(upower -e | grep -v DisplayDevice)

# --- Solaar devices (Logitech Bolt/Unifying) ---
if command -v solaar &>/dev/null; then
    wait "$SOLAAR_PID"
    current_device=""
    while IFS= read -r line; do
        # Top-level device line: "  1: Device Name"  (exactly 2 spaces indent)
        if [[ "$line" =~ ^"  "[0-9]+:[[:space:]](.+)$ ]]; then
            current_device="${BASH_REMATCH[1]}"
        fi
        # Top-level battery summary line: "     Battery: 85%, ..."  (exactly 5 spaces)
        if [[ "$line" =~ ^"     Battery: "([0-9]+)% ]] && [[ -n "$current_device" ]]; then
            level="${BASH_REMATCH[1]}"
            device_id="solaar_$(echo "$current_device" | tr -dc '[:alnum:]_-')"
            notify_if_low "$device_id" "$current_device" "$level"
            current_device=""
        fi
    done < "$SOLAAR_TMP"
    rm -f "$SOLAAR_TMP"
fi

# --- jLink devices (Jabra headsets) ---
if command -v jlink &>/dev/null; then
    jlink_output=$(jlink --battery 2>/dev/null)
    if [[ -n "$jlink_output" ]]; then
        level=$(echo "$jlink_output" | grep -oP '"level":\s*\K\d+')
        device=$(echo "$jlink_output" | grep -oP '"device":\s*"\K[^"]+')
        if [[ -n "$level" && -n "$device" ]]; then
            device_id="jlink_$(echo "$device" | tr -dc '[:alnum:]_-')"
            notify_if_low "$device_id" "$device" "$level"
        fi
    fi
fi
