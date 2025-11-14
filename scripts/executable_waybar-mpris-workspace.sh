#!/usr/bin/env bash

# Get active mpris player
active_player=$(playerctl -l 2>/dev/null | head -n1)

if [ -z "$active_player" ]; then
    echo ""
    exit 0
fi

# Get player status and metadata
status=$(playerctl -p "$active_player" status 2>/dev/null)
title=$(playerctl -p "$active_player" metadata title 2>/dev/null)
artist=$(playerctl -p "$active_player" metadata artist 2>/dev/null)

if [ "$status" != "Playing" ] && [ "$status" != "Paused" ]; then
    echo ""
    exit 0
fi

# Get PID of the player application
player_pid=$(pgrep -f "$active_player" | head -n1)

# If we can't find by name, try to get from playerctl metadata
if [ -z "$player_pid" ]; then
    # Try different common player names
    case "$active_player" in
        *spotify*)
            player_pid=$(pgrep -i spotify | head -n1)
            ;;
        *firefox*)
            player_pid=$(pgrep -i firefox | head -n1)
            ;;
        *chrome*)
            player_pid=$(pgrep -i chrome | head -n1)
            ;;
        *mpv*)
            player_pid=$(pgrep -i mpv | head -n1)
            ;;
    esac
fi

# Get workspace information from Sway
workspace=""
if [ -n "$player_pid" ]; then
    # Get the window ID for the player process
    window_id=$(swaymsg -t get_tree | jq -r ".. | select(.pid? == $player_pid) | .id" | head -n1)
    
    if [ -n "$window_id" ]; then
        # Get workspace number/name from the window
        workspace=$(swaymsg -t get_tree | jq -r ".. | select(.type? == \"workspace\") | select(.. | .id? == $window_id) | .num // .name" | head -n1)
    fi
    
    # If not found, check child processes
    if [ -z "$workspace" ]; then
        child_pids=$(pgrep -P "$player_pid")
        for child_pid in $child_pids; do
            window_id=$(swaymsg -t get_tree | jq -r ".. | select(.pid? == $child_pid) | .id" | head -n1)
            if [ -n "$window_id" ]; then
                workspace=$(swaymsg -t get_tree | jq -r ".. | select(.type? == \"workspace\") | select(.. | .id? == $window_id) | .num // .name" | head -n1)
                if [ -n "$workspace" ]; then
                    break
                fi
            fi
        done
    fi
fi

# Format output
if [ "$status" = "Playing" ]; then
    status_icon="▶"
else
    status_icon="⏸"
fi

# Build dynamic text
dynamic=""
if [ -n "$title" ]; then
    dynamic="$title"
    if [ -n "$artist" ]; then
        dynamic="$dynamic - $artist"
    fi
fi

# Truncate if too long
if [ ${#dynamic} -gt 40 ]; then
    dynamic="${dynamic:0:37}..."
fi

# Add workspace if found
if [ -n "$workspace" ]; then
    echo "$status_icon $dynamic [$workspace]"
else
    echo "$status_icon $dynamic"
fi
