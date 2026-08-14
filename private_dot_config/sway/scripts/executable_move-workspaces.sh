#!/usr/bin/env bash
# Move workspaces 1-9 to the external monitor, keep workspace 10 on the laptop.
# With multiple externals, picks the largest by pixel count.
# Safe to call when undocked (no-op if no external output found).
#
# Driven off the actual workspace list rather than a literal 1-9 loop: switching
# through numbers that don't exist materializes them, and sway garbage-collects
# whichever empty workspace was focused. Restoring focus afterwards then
# re-creates it on whatever output happens to be focused, which is how a
# workspace ended up stranded on the laptop panel.
#
# Set MOVE_WORKSPACES_DEBUG=1 to trace decisions on stderr.

set -euo pipefail

readonly DEBUG=${MOVE_WORKSPACES_DEBUG:-0}

laptop_output=""
external_output=""

log() {
    [ "$DEBUG" = "1" ] || return 0
    printf 'move-workspaces: %s\n' "$*" >&2
}

# Run a sway command, reporting failures instead of swallowing them.
sway_do() {
    local err
    if ! err=$(swaymsg -- "$1" 2>&1 >/dev/null); then
        printf 'move-workspaces: command failed: %s: %s\n' "$1" "$err" >&2
        return 1
    fi
    return 0
}

# Where does this workspace number belong? Empty means "leave it alone".
target_for() {
    case $1 in
        [1-9]) printf '%s' "$external_output" ;;
        10) printf '%s' "$laptop_output" ;;
        *) printf '' ;;
    esac
}

# One reconciliation pass. Prints the number of moves it performed.
reconcile() {
    local moves=0 num name output target workspaces

    workspaces=$(swaymsg -t get_workspaces 2>/dev/null) || { echo 0; return 0; }

    while IFS=$'\t' read -r num name output; do
        [ -n "$num" ] || continue
        target=$(target_for "$num")
        [ -n "$target" ] || continue
        [ "$output" != "$target" ] || continue

        log "moving workspace $name from $output to $target"
        if sway_do "workspace --no-auto-back-and-forth \"$name\", move workspace to output \"$target\""; then
            moves=$((moves + 1))
        fi
    done < <(printf '%s' "$workspaces" | jq -r '.[] | [.num, .name, .output] | @tsv')

    echo "$moves"
}

# Converge: moving the last workspace off an output makes sway auto-create a
# replacement there, so a single pass is not a fixpoint.
converge() {
    local pass moves
    for pass in 1 2 3; do
        moves=$(reconcile)
        log "pass $pass: $moves move(s)"
        [ "$moves" -gt 0 ] || return 0
    done
    log "did not converge after 3 passes"
}

main() {
    local outputs
    outputs=$(swaymsg -t get_outputs 2>/dev/null) || exit 0

    laptop_output=$(printf '%s' "$outputs" | jq -r '
        [.[] | select(.active and (.name | test("^eDP")))] | first // empty | .name
    ')

    # Find the external output with the most pixels (width * height)
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

    log "laptop=${laptop_output:-<none>} external=${external_output:-<none>}"
    [ -n "$external_output" ] || exit 0

    local focused
    focused=$(swaymsg -t get_workspaces 2>/dev/null | jq -r '.[] | select(.focused) | .name')
    log "focused workspace: ${focused:-<none>}"

    converge

    # The old literal loop created workspace 10 as a side effect; do it
    # explicitly now. The `workspace 10 output eDP-1` assignment places it.
    if [ -n "$laptop_output" ] &&
        ! swaymsg -t get_workspaces 2>/dev/null | jq -e 'any(.[]; .num == 10)' >/dev/null; then
        log "creating workspace 10 on $laptop_output"
        sway_do "workspace --no-auto-back-and-forth \"10\", move workspace to output \"$laptop_output\"" || true
    fi

    # Restore focus last. If the saved workspace was garbage-collected during
    # the run, focusing the external first makes sway re-create it there rather
    # than on whichever output we happen to be sitting on.
    if [ -n "$focused" ]; then
        if [ "$focused" = "10" ]; then
            sway_do "workspace --no-auto-back-and-forth \"10\"" || true
        else
            sway_do "focus output \"$external_output\", workspace --no-auto-back-and-forth \"$focused\"" || true
        fi
    fi

    # Insurance: the restore itself may have created a workspace.
    converge
}

main "$@"
