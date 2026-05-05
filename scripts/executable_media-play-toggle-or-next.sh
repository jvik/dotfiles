#!/usr/bin/env bash

set -euo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/media-key"
STATE_FILE="$STATE_DIR/playpause-double.state"
WINDOW_MS=350
SLEEP_SECONDS="0.35"

mkdir -p "$STATE_DIR"

now_ms() {
  date +%s%3N
}

read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    read -r last_ts last_token < "$STATE_FILE" || true
  else
    last_ts=0
    last_token=""
  fi
}

token="$$-$(date +%s%N)"
now="$(now_ms)"

read_state

# If the previous press was recent, treat this as a double press.
if [[ "$last_ts" =~ ^[0-9]+$ ]] && (( last_ts > 0 )) && (( now - last_ts <= WINDOW_MS )); then
  printf '%s %s\n' "$now" "$token" > "$STATE_FILE"
  exec playerctl next
fi

printf '%s %s\n' "$now" "$token" > "$STATE_FILE"
sleep "$SLEEP_SECONDS"

read_state
if [[ "$last_token" == "$token" ]]; then
  exec playerctl play-pause
fi

exit 0
