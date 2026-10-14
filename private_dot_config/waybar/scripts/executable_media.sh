#!/usr/bin/env bash
# Now-playing for waybar's custom/media, in place of the built-in mpris module.
#
# waybar 0.15's mpris module leaves its libplayerctl signal handlers connected
# when a bar is destroyed (output removed, e.g. undocking). The next player
# event then calls Gtk::Widget::set_visible on the freed widget and segfaults
# waybar. Out of process, a playerctl problem can only take down this script,
# which waybar restarts (restart-interval).
#
# Emits one JSON line per player change; empty text hides the module.

set -uo pipefail

MAX_LEN=40
SEP=$'\x1f' # not tab: tab is IFS whitespace, so empty fields would collapse

player_icon() {
    case "$1" in
        firefox) printf '' ;;
        chromium | google-chrome) printf '' ;;
        spotify) printf '' ;;
        mpv | vlc | plex) printf '\U0001f3ac' ;;
        *) printf '\U0001f3b5' ;;
    esac
}

# Pango markup escape; custom module text and tooltip are both parsed as markup.
# `\&`: bash 5.2's patsub_replacement makes a bare & mean the matched text.
escape() {
    local s=${1//&/\&amp;}
    s=${s//</\&lt;}
    printf '%s' "${s//>/\&gt;}"
}

emit() { jq -cn --arg text "$1" --arg tooltip "$2" --arg alt "$3" \
    '{text: $text, tooltip: $tooltip, alt: $alt, class: $alt}'; }

# playerctl prints nothing until a player appears; start out hidden.
emit "" "" ""

while IFS=$SEP read -r status player title artist album; do
    if [ -z "$status" ]; then
        emit "" "" ""
        continue
    fi

    dynamic=""
    for part in "$title" "$artist" "$album"; do
        [ -n "$part" ] || continue
        dynamic+=${dynamic:+ - }$part
    done
    short=$dynamic
    [ "${#short}" -le "$MAX_LEN" ] || short="${short:0:MAX_LEN-1}…"

    text="$(escape "$short") $(player_icon "$player")"
    [ "$status" != "Paused" ] || text="<i>$(escape "$short")</i> $(player_icon "$player")"

    status=${status,,}
    emit "$text" "$(escape "$player ($status): $dynamic")" "$status"
done < <(playerctl --follow metadata \
    --format "{{status}}$SEP{{playerName}}$SEP{{title}}$SEP{{artist}}$SEP{{album}}" 2>/dev/null)
