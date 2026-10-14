#!/usr/bin/env bash
# Now-playing for waybar's custom/media, in place of the built-in mpris module.
#
# waybar 0.15's mpris module leaves its libplayerctl signal handlers connected
# when a bar is destroyed (output removed, e.g. undocking). The next player
# event then calls Gtk::Widget::set_visible on the freed widget and segfaults
# waybar. Out of process, a playerctl problem can only take down this script,
# which waybar restarts (restart-interval).
#
# Follows playerctld rather than "any player": a plain `playerctl --follow`
# started with no player running never picked up one that appeared later.
# playerctld is always there (D-Bus activated) and proxies the most recently
# active player, so players coming and going are its problem, not ours.
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

# The player playerctld is proxying, as a bus name minus the MPRIS prefix and
# any per-process suffix: org.mpris.MediaPlayer2.firefox.instance_1_286 ->
# firefox. Through playerctld, {{playerName}} is always just "playerctld".
# The busctl call also D-Bus-activates playerctld if it isn't running yet.
active_player() {
    local name
    name=$(busctl --user get-property org.mpris.MediaPlayer2.playerctld \
        /org/mpris/MediaPlayer2 com.github.altdesktop.playerctld PlayerNames 2>/dev/null |
        grep -o '"[^"]*"' | head -1 | tr -d '"')
    name=${name#org.mpris.MediaPlayer2.}
    printf '%s' "${name%%.instance*}"
}

# Two event sources on one stream (lines are short, so writes don't interleave):
#  - playerctl's metadata lines, for anything playing;
#  - a marker on playerctld's ActivePlayerChangeEnd. When the last player quits,
#    playerctld only *invalidates* its properties, which playerctl --follow
#    does not print, so without this the module stays up after the player exits.
CHANGED=__active_player_changed__
events() {
    playerctl --player=playerctld --follow metadata \
        --format "{{status}}$SEP{{title}}$SEP{{artist}}$SEP{{album}}" 2>/dev/null &
    dbus-monitor --session "type='signal',sender='org.mpris.MediaPlayer2.playerctld',member='ActivePlayerChangeEnd'" 2>/dev/null |
        while IFS= read -r line; do
            [[ $line == *member=ActivePlayerChangeEnd* ]] && echo "$CHANGED"
        done
}

emit() { jq -cn --arg text "$1" --arg tooltip "$2" --arg alt "$3" \
    '{text: $text, tooltip: $tooltip, alt: $alt, class: $alt}'; }

# playerctl prints nothing until a player appears; start out hidden.
emit "" "" ""
active_player >/dev/null

while IFS=$SEP read -r status title artist album; do
    if [ "$status" = "$CHANGED" ]; then
        # A new player's metadata arrives as its own line; only handle "none left".
        [ -n "$(active_player)" ] || emit "" "" ""
        continue
    fi

    dynamic=""
    for part in "$title" "$artist" "$album"; do
        [ -n "$part" ] || continue
        dynamic+=${dynamic:+ - }$part
    done

    # No player, or one with nothing loaded: hide rather than show a bare icon.
    if [ -z "$status" ] || [ -z "$dynamic" ]; then
        emit "" "" ""
        continue
    fi

    player=$(active_player)
    short=$dynamic
    [ "${#short}" -le "$MAX_LEN" ] || short="${short:0:MAX_LEN-1}…"

    text="$(escape "$short") $(player_icon "$player")"
    [ "$status" != "Paused" ] || text="<i>$(escape "$short")</i> $(player_icon "$player")"

    status=${status,,}
    emit "$text" "$(escape "$player ($status): $dynamic")" "$status"
done < <(events)
