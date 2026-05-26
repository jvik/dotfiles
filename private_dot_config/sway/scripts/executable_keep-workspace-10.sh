#!/usr/bin/env bash
# Keep workspace 10 alive by recreating it whenever it becomes empty.
# Listens to sway workspace events and reacts to "empty" on ws 10.

set -euo pipefail

ensure_ws10() {
    if ! swaymsg -t get_workspaces | jq -e '.[] | select(.num == 10)' >/dev/null 2>&1; then
        swaymsg 'workspace 10; workspace back_and_forth'
    fi
}

# Wait for sway to be fully ready
sleep 2
ensure_ws10

# React only when workspace 10 becomes empty
swaymsg -t subscribe '["workspace"]' \
    | jq --unbuffered -c 'select(.change == "empty" and .current.num == 10)' \
    | while read -r _; do
        sleep 0.3
        ensure_ws10
    done
