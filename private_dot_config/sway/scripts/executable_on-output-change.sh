#!/usr/bin/env bash
# Reconcile the session after the output topology changes.
#
#   (no args)  daemon: watch sway output events, debounce the modeset burst,
#              then move workspaces home and re-fill tiling containers.
#   --once     one reconcile pass, then exit (keybinding / sway startup).
#
# Started as a systemd user unit, NOT as
#   exec_always "pkill -f on-output-change.sh; ~/.../on-output-change.sh"
# sway runs exec_always through `sh -c "<the whole string>"`, so that shell's
# own argv contains the pattern and pkill -f SIGTERMs it before it reaches the
# `;`. That is why the fix-tiling watcher this replaces was never running.

set -uo pipefail

SCRIPTS="$HOME/.config/sway/scripts"
DEBOUNCE=${OUTPUT_CHANGE_DEBOUNCE:-0.7}

# systemd user units only see sway's env if it was imported; find it ourselves.
if [ -z "${SWAYSOCK:-}" ]; then
    SWAYSOCK=$(find "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" -maxdepth 1 \
        -name 'sway-ipc.*.sock' -printf '%T@ %p\n' 2>/dev/null |
        sort -rn | head -1 | cut -d' ' -f2-)
    export SWAYSOCK
fi

log() { printf 'on-output-change: %s\n' "$*" >&2; }

# Topology fingerprint. Deliberately excludes .power: swayidle's
# `output * power off` after 300s also emits output events, and reconciling on
# a DPMS cycle would yank the focused workspace every five minutes.
fingerprint() {
    swaymsg -t get_outputs -r 2>/dev/null |
        jq -Sc 'map({n: .name, a: .active, r: .rect}) | sort_by(.n)' 2>/dev/null
}

reconcile() {
    local try rc
    for try in 1 2 3; do
        "$SCRIPTS/move-workspaces.sh"
        rc=$?
        [ "$rc" -eq 0 ] && break
        # 75 = EX_TEMPFAIL: outputs had no mode yet, the modeset is still in
        # flight. Retry anything else too - the alternative is workspaces
        # stranded until the user reaches for reload.
        log "move-workspaces rc=$rc (try $try)"
        sleep 1
    done
    swaymsg -q "[tiling] resize set 0 0" || true
}

if [ "${1:-}" = "--once" ]; then
    reconcile
    exit 0
fi

prev=$(fingerprint)

# `< <(...)` rather than a pipe so `prev` survives in the main shell.
while read -r _; do
    # Drain the modeset burst. This `read -t` consumes from the same fd as the
    # outer read, so no event can outrun us; it exits only on quiet or EOF, and
    # the reconcile below always runs afterwards. Event bodies are ignored on
    # purpose: output events exceed PIPE_BUF, so a line may be split, and
    # mis-framing must only affect how often we run, never whether we run.
    while read -r -t "$DEBOUNCE" _; do :; done

    cur=$(fingerprint)
    [ "$cur" != "$prev" ] || continue
    prev=$cur
    log "topology changed, reconciling"
    reconcile
done < <(swaymsg -t subscribe '["output"]' --monitor)

log "output event stream ended"
exit 1
