#!/usr/bin/env bash

# Append a kanshi profile derived from current Sway output layout.
# Usage: kanshi-append-config.sh [profile-name] [kanshi-config-path]

set -euo pipefail

DEFAULT_CONFIG="$HOME/.local/share/chezmoi/private_dot_config/kanshi/config"
MARKER="# Generated profiles"

error_exit() {
    echo "Error: $1" >&2
    exit "${2:-1}"
}

print_usage() {
    echo "Usage: $0 [profile-name] [kanshi-config-path]"
    echo "Example: $0"
    echo "Example: $0 office-dock ~/.local/share/chezmoi/private_dot_config/kanshi/config"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || error_exit "Missing required command: $1"
}

sanitize_name() {
    local raw="$1"

    raw=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
    raw=$(printf '%s' "$raw" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')

    if [ -z "$raw" ]; then
        raw="generated-profile"
    fi

    printf '%s\n' "$raw"
}

ensure_generated_marker() {
    local config_path="$1"

    if grep -Fxq "$MARKER" "$config_path"; then
        return
    fi

    if [ -s "$config_path" ] && [ "$(tail -c 1 "$config_path" || true)" != "" ]; then
        printf '\n' >> "$config_path"
    fi

    printf '\n%s\n' "$MARKER" >> "$config_path"
}

find_unique_profile_name() {
    local base_name="$1"
    local config_path="$2"
    local candidate="$base_name"
    local idx=2

    while grep -Eq "^profile[[:space:]]+${candidate}[[:space:]]*\\{" "$config_path"; do
        candidate="${base_name}-${idx}"
        idx=$((idx + 1))
    done

    printf '%s\n' "$candidate"
}

profile_exists() {
    local profile_name="$1"
    local config_path="$2"

    grep -Eq "^profile[[:space:]]+${profile_name}[[:space:]]*\\{" "$config_path"
}

main() {
    local requested_name="${1:-}"
    local config_path="${2:-$DEFAULT_CONFIG}"
    local outputs_json
    local outputs_count
    local external_joined
    local profile_base
    local profile_name
    local output_lines

    if [ "$requested_name" = "-h" ] || [ "$requested_name" = "--help" ]; then
        print_usage
        exit 0
    fi

    require_cmd swaymsg
    require_cmd jq

    [ -f "$config_path" ] || error_exit "Kanshi config does not exist: $config_path"
    [ -w "$config_path" ] || error_exit "Kanshi config is not writable: $config_path"

    outputs_json=$(swaymsg -t get_outputs 2>/dev/null) || error_exit "Failed to query sway outputs"

    outputs_count=$(printf '%s' "$outputs_json" | jq -r '
        [
            .[]
            | select(.active == true and .current_mode != null)
            | select((.position != null) or (.rect != null))
        ]
        | length
    ')
    [ "$outputs_count" -gt 0 ] || error_exit "No active outputs found"

    if [ -n "$requested_name" ]; then
        profile_base=$(sanitize_name "$requested_name")
    else
        external_joined=$(printf '%s' "$outputs_json" | jq -r '
            [
                .[]
                | select(.active == true and .current_mode != null)
                | select((.position != null) or (.rect != null))
                | select((.name | test("^eDP")) | not)
            ]
            | sort_by((if .position != null then .position.x else .rect.x end), (if .position != null then .position.y else .rect.y end), .name)
            | map(.name)
            | join("-")
        ')

        if [ -n "$external_joined" ]; then
            profile_base=$(sanitize_name "$external_joined")
        else
            profile_base="laptop"
        fi

        # Quick guard: if an auto-derived source profile already exists,
        # do not append another generated profile for the same source.
        if profile_exists "$profile_base" "$config_path"; then
            echo "Profile for current source already exists: $profile_base"
            exit 0
        fi
    fi

    output_lines=$(printf '%s' "$outputs_json" | jq -r '
        def output_name:
            if (.make // "") != "" and (.model // "") != "" and (.serial // "") != "" and .serial != "Unknown" then
                "\(.make) \(.model) \(.serial)"
            else
                .name
            end;

        def pos_x:
            if .position != null and .position.x != null then .position.x
            elif .rect != null and .rect.x != null then .rect.x
            else 0
            end;

        def pos_y:
            if .position != null and .position.y != null then .position.y
            elif .rect != null and .rect.y != null then .rect.y
            else 0
            end;

        def refresh_hz:
            if .current_mode.refresh != null then (.current_mode.refresh / 1000)
            elif .current_mode.refresh_rate != null then (.current_mode.refresh_rate / 1000)
            else null
            end;

        def fmt_hz($v):
            if $v == null then ""
            elif ($v | floor) == $v then (($v | floor) | tostring)
            else ($v | tostring | sub("0+$"; "") | sub("\\.$"; ""))
            end;

        [
            .[]
            | select(.active == true and .current_mode != null)
            | select((.position != null) or (.rect != null))
        ]
        | sort_by(pos_x, pos_y, .name)
        | .[]
        | (refresh_hz) as $hz
        | ("\(.current_mode.width)x\(.current_mode.height)" + (if $hz == null then "" else "@\(fmt_hz($hz))Hz" end)) as $mode
        | "    output \"\(output_name)\" enable mode \($mode) position \(pos_x),\(pos_y)"
    ')

    [ -n "$output_lines" ] || error_exit "Could not generate output lines from sway outputs"

    ensure_generated_marker "$config_path"
    profile_name=$(find_unique_profile_name "$profile_base" "$config_path")

    {
        printf '\nprofile %s {\n' "$profile_name"
        printf '%s\n' "$output_lines"
        printf '}\n'
    } >> "$config_path"

    echo "Appended profile '$profile_name' to $config_path"
    echo "Remember to run 'chezmoi apply' and reload kanshi to use the new profile."

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -t 2000 "Kanshi" "Generated profile: $profile_name"
    fi
}

main "$@"
