#!/usr/bin/env bash

offset=0

show_month() {
    clear
    local target
    target=$(date -d "$(date +%Y-%m-01) ${offset:+${offset} month}" +"%m %Y" 2>/dev/null \
          || date -v "${offset}m" +"%m %Y" 2>/dev/null)
    local month year
    month=$(echo "$target" | cut -d' ' -f1)
    year=$(echo "$target"  | cut -d' ' -f2)
    ncal -b -w -M "$month" "$year"
    printf '\n ← → : forrige/neste'
    printf '\n q : lukk\n'
}

old_stty=$(stty -g)
stty -echo -icanon min 1 time 0
trap 'stty "$old_stty"' EXIT INT TERM

show_month

while true; do
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.1 seq
        key="$key$seq"
    fi
    case "$key" in
        $'\x1b[D'|$'\x1b[A'|h|k) offset=$((offset - 1)); show_month ;;
        $'\x1b[C'|$'\x1b[B'|l|j) offset=$((offset + 1)); show_month ;;
        q|$'\x1b') break ;;
    esac
done
