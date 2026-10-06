#!/usr/bin/env bash

DEVICE="/org/freedesktop/UPower/devices/battery_BAT0"
REFRESH_SECONDS=2
PAGE=10

KEY_UP=$'\x1b[A'
KEY_DOWN=$'\x1b[B'
KEY_PAGE_UP=$'\x1b[5~'
KEY_PAGE_DOWN=$'\x1b[6~'

offset=0

# Scrolls inside the script: the periodic redraw clears the terminal's own scrollback.
show_battery() {
    local lines visible last i
    mapfile -t lines < <(upower -i "$DEVICE")
    visible=$(( $(tput lines) - 2 ))   # Leave room for the key hint.

    last=$(( ${#lines[@]} - visible ))
    (( offset > last )) && offset=$last
    (( offset < 0 )) && offset=0

    clear
    for (( i = offset; i < offset + visible && i < ${#lines[@]}; i++ )); do
        printf '%s\n' "${lines[i]}"
    done
    printf '\n ↑ ↓ / j k : rull   q : lukk'
}

# Arrow and page keys arrive as an escape sequence, so read the rest of it
# instead of treating the lone ESC byte as a key. Fails if nothing is pressed.
read_key() {
    local seq
    IFS= read -rsn1 -t "$REFRESH_SECONDS" key || return 1
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn3 -t 0.05 seq
        key="$key$seq"
    fi
}

old_stty=$(stty -g)
stty -echo -icanon min 1 time 0
trap 'stty "$old_stty"' EXIT INT TERM

while true; do
    show_battery
    read_key || continue
    case "$key" in
        "$KEY_UP"|k)          offset=$(( offset - 1 )) ;;
        "$KEY_DOWN"|j)        offset=$(( offset + 1 )) ;;
        "$KEY_PAGE_UP")       offset=$(( offset - PAGE )) ;;
        "$KEY_PAGE_DOWN"|' ') offset=$(( offset + PAGE )) ;;
        g)                    offset=0 ;;
        G)                    offset=999999 ;;  # Clamped to the last page.
        q)                    break ;;
    esac
done
