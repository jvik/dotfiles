#!/usr/bin/env bash

# Append a kanshi profile derived from current Sway output layout.
# Usage: kanshi-append-config.sh [profile-name] [kanshi-config-path]
#
# External outputs are capped at KANSHI_MAX_REFRESH Hz. Recording a monitor's
# top refresh is what produced the 5120x1440@165.001Hz profile that left the
# internal panel unable to come back after a DPMS off -- at that mode the DRM
# config has no room left for eDP-1.

set -euo pipefail

DEFAULT_CONFIG="$HOME/.local/share/chezmoi/private_dot_config/kanshi/config"
MARKER="# Generated profiles"
# New profiles are inserted before this one: kanshi takes the first match, so a
# profile written after the catch-all would be unreachable.
FALLBACK_PROFILE="fallback-docked"
MAX_REFRESH_MHZ=$(( ${KANSHI_MAX_REFRESH:-120} * 1000 ))

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

    raw=$(printf '%s' "$raw" | sed -E 's/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')

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
            def source_id:
                if (.serial // "") != "" and .serial != "Unknown" then
                    .serial
                else
                    .name
                end;

            [
                .[]
                | select(.active == true and .current_mode != null)
                | select((.position != null) or (.rect != null))
                | select((.name | test("^eDP")) | not)
            ]
            | sort_by((if .position != null then .position.x else .rect.x end), (if .position != null then .position.y else .rect.y end), .name)
            | map(source_id)
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

    output_lines=$(printf '%s' "$outputs_json" | jq -r --argjson max_refresh "$MAX_REFRESH_MHZ" '
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

        def fmt_hz($mhz):
            ($mhz / 1000) as $v
            | if ($v | floor) == $v then (($v | floor) | tostring)
              else ($v | tostring | sub("0+$"; "") | sub("\\.$"; ""))
              end;

        def mode_str($w; $h; $mhz):
            "\($w)x\($h)" + (if $mhz == null then "" else "@\(fmt_hz($mhz))Hz" end);

        [
            .[]
            | select(.active == true and .current_mode != null)
            | select((.position != null) or (.rect != null))
        ]
        | sort_by(pos_x, pos_y, .name)
        | .[]
        | . as $o
        | ($o.current_mode) as $cm
        | ($cm.refresh // $cm.refresh_rate) as $current
        | (($o.name | test("^eDP")) | not) as $is_external
        # Highest advertised refresh at this resolution that is within the cap.
        | (if $is_external and $current != null and $current > $max_refresh then
               ([$o.modes[]? | select(.width == $cm.width and .height == $cm.height) | .refresh]
                | map(select(. <= $max_refresh)) | max)
           else null end) as $capped
        | "    output \"\($o | output_name)\" enable mode \(mode_str($cm.width; $cm.height; $capped // $current)) position \($o | pos_x),\($o | pos_y)"
          + (if $capped == null then ""
             else "\n    # capped from \(mode_str($cm.width; $cm.height; $current)); raise KANSHI_MAX_REFRESH to keep it"
             end)
    ')

    [ -n "$output_lines" ] || error_exit "Could not generate output lines from sway outputs"

    profile_name=$(find_unique_profile_name "$profile_base" "$config_path")

    local profile_text
    profile_text=$(
        printf '\nprofile %s {\n' "$profile_name"
        printf '%s\n' "$output_lines"
        printf '}\n'
    )

    # Insert before the catch-all rather than appending. kanshi takes the first
    # matching profile, so anything written after `profile fallback-docked`
    # would never match.
    if grep -q "^profile $FALLBACK_PROFILE {" "$config_path"; then
        local tmp
        tmp=$(mktemp) || error_exit "Could not create temp file"
        awk -v anchor="^profile $FALLBACK_PROFILE \\{" -v block="$profile_text" '
            !done && $0 ~ anchor { print block; done = 1 }
            { print }
        ' "$config_path" > "$tmp" || { rm -f "$tmp"; error_exit "Failed to rewrite $config_path"; }
        cat "$tmp" > "$config_path" || { rm -f "$tmp"; error_exit "Failed to write $config_path"; }
        rm -f "$tmp"
        echo "Inserted profile '$profile_name' before $FALLBACK_PROFILE in $config_path"
    else
        printf '%s\n' "$profile_text" >> "$config_path"
        echo "Appended profile '$profile_name' to $config_path"
    fi

    echo "Run 'chezmoi apply ~/.config/kanshi/config' to deploy it; the"
    echo "run_onchange hook restarts kanshi for you."

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -t 2000 "Kanshi" "Generated profile: $profile_name"
    fi
}

main "$@"
