#!/usr/bin/env sh
# Dynamic CPU temperature sensor for Waybar.
# Finds the correct hwmon sensor by name instead of relying on a hardcoded path.

CRITICAL=80

# Search for a known CPU temperature sensor by hwmon name
for hwmon in /sys/class/hwmon/hwmon*; do
    name=$(cat "$hwmon/name" 2>/dev/null)
    case "$name" in
        coretemp|k10temp|zenpower|acpitz)
            temp_file="$hwmon/temp1_input"
            if [ -f "$temp_file" ]; then
                temp=$(( $(cat "$temp_file") / 1000 ))
                if [ "$temp" -ge 80 ]; then
                    icon="󰸁"
                elif [ "$temp" -ge 60 ]; then
                    icon="󰔏"
                else
                    icon="�"
                fi
                class=""
                [ "$temp" -ge "$CRITICAL" ] && class="critical"
                printf '{"text": "%s %d°C", "class": "%s", "tooltip": "%s: %d°C"}\n' \
                    "$icon" "$temp" "$class" "$name" "$temp"
                exit 0
            fi
            ;;
    esac
done

# Fallback: thermal_zone0
temp=$(( $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0) / 1000 ))
printf '{"text": "󰔍 %d°C", "class": "", "tooltip": "thermal_zone0: %d°C"}\n' "$temp" "$temp"
