#!/usr/bin/env bash
# Move workspaces 1-9 to the external monitor, keep workspace 10 on the laptop.
# With multiple externals, picks the largest by pixel count.
# Safe to call when undocked (no-op if no external output found).

set -euo pipefail

main() {
    local outputs
    outputs=$(swaymsg -t get_outputs 2>/dev/null) || exit 0

    local laptop_output
    laptop_output=$(printf '%s' "$outputs" | jq -r '
        [.[] | select(.active and (.name | test("^eDP")))] | first // empty | .name
    ')

    # Find the external output with the most pixels (width * height)
    local external_output
    external_output=$(printf '%s' "$outputs" | jq -r '
        [
            .[]
            | select(.active and .current_mode != null)
            | select((.name | test("^eDP")) | not)
        ]
        | sort_by(-(.current_mode.width * .current_mode.height))
        | first // empty
        | .name
    ')

    [ -n "$external_output" ] || exit 0

    for i in 1 2 3 4 5 6 7 8 9; do
        swaymsg "workspace $i, move workspace to output '$external_output'" 2>/dev/null || true
    done

    if [ -n "$laptop_output" ]; then
        swaymsg "workspace 10, move workspace to output '$laptop_output'" 2>/dev/null || true
    fi
}

main "$@"
