#!/usr/bin/env bash
# Move workspaces 1-9 to the primary monitor, keep workspace 10 on the laptop.
# The primary is the largest external by pixel count, or the laptop panel when
# undocked -- so this pulls workspaces back home on unplug, not just out on plug.
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
readonly EX_TEMPFAIL=75

# Serialise: the output watcher, the exec_always at sway start and the
# mod+Shift+w binding can all fire inside the same second.
exec 9>"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/move-workspaces.lock"
flock -w 10 9 || exit 0

laptop_output=""
external_output=""
primary_output=""

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
        [1-9]) printf '%s' "$primary_output" ;;
        10) printf '%s' "$laptop_output" ;;
        *) printf '' ;;
    esac
}

# One reconciliation pass. Prints the number of moves it performed.
reconcile() {
    local moves=0 num name output target workspaces

    workspaces=$(swaymsg -t get_workspaces -r 2>/dev/null) || { echo 0; return 0; }

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
# Prints the total number of moves, so the caller can tell "nothing happened"
# from "the layout changed" and leave focus alone in the former case.
converge() {
    local pass moves total=0
    for pass in 1 2 3; do
        moves=$(reconcile)
        log "pass $pass: $moves move(s)"
        total=$((total + moves))
        [ "$moves" -gt 0 ] || break
    done
    echo "$total"
}

main() {
    local outputs
    outputs=$(swaymsg -t get_outputs -r 2>/dev/null) || exit 0

    # Mid-modeset guard. An output that is enabled but has no mode yet means the
    # topology is still in flight; picking a primary now would drag every
    # workspace onto the wrong panel and then drag it back one event later.
    if printf '%s' "$outputs" |
        jq -e 'any(.[]; .active and .current_mode == null)' >/dev/null 2>&1; then
        log "outputs still settling"
        exit "$EX_TEMPFAIL"
    fi

    # `|| ...=""` on both: pipefail + set -e would otherwise kill the script
    # silently on a transient jq failure, mid-reconcile.
    laptop_output=$(printf '%s' "$outputs" | jq -r '
        [.[] | select(.active and .current_mode != null and (.name | test("^eDP")))]
        | first // empty | .name
    ' 2>/dev/null) || laptop_output=""

    # Find the external output with the most pixels (width * height)
    external_output=$(printf '%s' "$outputs" | jq -r '
        [
            .[]
            | select(.active and .current_mode != null)
            | select((.name | test("^(eDP|HEADLESS)")) | not)
        ]
        | sort_by(-(.current_mode.width * .current_mode.height))
        | first // empty
        | .name
    ' 2>/dev/null) || external_output=""

    primary_output=${external_output:-$laptop_output}
    log "laptop=${laptop_output:-<none>} external=${external_output:-<none>} primary=${primary_output:-<none>}"

    # No usable output: mid-modeset, or the dock is gone with the lid shut.
    # sway has parked the workspaces on its internal fallback output, where
    # get_workspaces cannot see them, and restores them by itself the moment any
    # output is enabled. There is nothing for us to do, and trying would only
    # fight the compositor.
    [ -n "$primary_output" ] || exit 0

    local focused
    focused=$(swaymsg -t get_workspaces -r 2>/dev/null |
        jq -r '.[] | select(.focused) | .name' 2>/dev/null) || focused=""
    log "focused workspace: ${focused:-<none>}"

    local moved created=0
    moved=$(converge)

    # The old literal loop created workspace 10 as a side effect; do it
    # explicitly now. The `workspace 10 output eDP-1` assignment places it.
    if [ -n "$laptop_output" ] &&
        ! swaymsg -t get_workspaces -r 2>/dev/null |
            jq -e 'any(.[]; .num == 10)' >/dev/null 2>&1; then
        log "creating workspace 10 on $laptop_output"
        sway_do "workspace --no-auto-back-and-forth \"10\", move workspace to output \"$laptop_output\"" &&
            created=1
    fi

    # Nothing moved -> do not touch focus. This script now runs on every output
    # event, and output events also fire on DPMS off/on; an unconditional focus
    # restore would switch the user's workspace every time the screen blanked.
    if [ "$moved" -eq 0 ] && [ "$created" -eq 0 ]; then
        log "no changes; leaving focus alone"
        exit 0
    fi

    # Restore focus last. If the saved workspace was garbage-collected during
    # the run, focusing the primary first makes sway re-create it there rather
    # than on whichever output we happen to be sitting on.
    if [ -n "$focused" ]; then
        if [ "$focused" = "10" ] && [ -n "$laptop_output" ]; then
            sway_do "workspace --no-auto-back-and-forth \"10\"" || true
        else
            sway_do "focus output \"$primary_output\", workspace --no-auto-back-and-forth \"$focused\"" || true
        fi
    fi

    # Insurance: the restore itself may have created a workspace.
    converge >/dev/null
    exit 0
}

main "$@"
