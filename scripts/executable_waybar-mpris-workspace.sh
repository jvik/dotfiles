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
length=$(playerctl -p "$active_player" metadata mpris:length 2>/dev/null)
position=$(playerctl -p "$active_player" position 2>/dev/null)

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
        *spotify*|*Spotify*)
            player_pid=$(pgrep -i spotify | head -n1)
            ;;
        *firefox*|*Firefox*)
            player_pid=$(pgrep -i firefox | head -n1)
            ;;
        *chrome*|*Chrome*)
            player_pid=$(pgrep -i chrome | head -n1)
            ;;
        *mpv*|*Mpv*)
            player_pid=$(pgrep -i mpv | head -n1)
            ;;
        *plexamp*|*Plexamp*)
            player_pid=$(pgrep -i plexamp | head -n1)
            ;;
        *)
            # Generic fallback - try to match player name
            player_name=$(echo "$active_player" | awk -F'.' '{print $1}')
            player_pid=$(pgrep -i "$player_name" | head -n1)
            ;;
    esac
fi

# Get workspace information from Sway
workspace=""
if [ -n "$player_pid" ]; then
    # Collect all PIDs related to the player (parent and children)
    all_pids="$player_pid"
    
    # Add all processes with the same name
    player_name=$(ps -p "$player_pid" -o comm= 2>/dev/null)
    if [ -n "$player_name" ]; then
        additional_pids=$(pgrep -x "$player_name" 2>/dev/null)
        if [ -n "$additional_pids" ]; then
            all_pids="$all_pids $additional_pids"
        fi
    fi
    
    # Add child processes
    child_pids=$(pgrep -P "$player_pid" 2>/dev/null)
    if [ -n "$child_pids" ]; then
        all_pids="$all_pids $child_pids"
    fi
    
    # Remove duplicates and try each PID
    all_pids=$(echo "$all_pids" | tr ' ' '\n' | sort -u | tr '\n' ' ')
    
    for pid in $all_pids; do
        # Get the window for this PID
        window_data=$(swaymsg -t get_tree | jq -r ".. | select(.pid?) | select(.pid == $pid) | .id" 2>/dev/null | head -n1)
        
        if [ -n "$window_data" ]; then
            # Find which workspace contains this window
            workspace=$(swaymsg -t get_tree | jq -r --arg wid "$window_data" '
                .. | 
                select(.type? == "workspace") | 
                select(.. | .id? == ($wid | tonumber)) | 
                .num // .name
            ' 2>/dev/null | head -n1)
            
            if [ -n "$workspace" ]; then
                break
            fi
        fi
    done
fi

# Determine player icon
player_icon="▶"
case "$active_player" in
    *spotify*)
        player_icon=""
        ;;
    *mpv*)
        player_icon="🎵"
        ;;
esac

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

# Truncate if too long (reserve space for workspace)
max_len=40
if [ -n "$workspace" ]; then
    max_len=35
fi

if [ ${#dynamic} -gt $max_len ]; then
    dynamic="${dynamic:0:$((max_len-3))}..."
fi

# Format length/duration
length_str=""
position_str=""
if [ -n "$length" ] && [ "$length" != "0" ]; then
    # Convert microseconds to mm:ss
    seconds=$((length / 1000000))
    minutes=$((seconds / 60))
    seconds=$((seconds % 60))
    length_str=$(printf "%d:%02d" $minutes $seconds)
fi

# Format current position
# Only show position for players that properly report it via MPRIS
# Plexamp has a bug where Position always reports 0
case "$active_player" in
    *plexamp*|*Plexamp*)
        # Plexamp doesn't properly report position, skip it
        position_str=""
        ;;
    *)
        if [ -n "$position" ]; then
            # playerctl position returns seconds as a float
            pos_total_seconds=$(printf "%.0f" "$position")
            pos_minutes=$((pos_total_seconds / 60))
            pos_seconds=$((pos_total_seconds % 60))
            position_str=$(printf "%d:%02d" $pos_minutes $pos_seconds)
        fi
        ;;
esac

# Combine position and length
time_str=""
if [ -n "$position_str" ] && [ -n "$length_str" ]; then
    time_str="$position_str/$length_str"
elif [ -n "$length_str" ]; then
    time_str="$length_str"
fi

# Build output with workspace info
if [ -n "$workspace" ]; then
    ws_info=" [$workspace]"
else
    ws_info=""
fi

# Apply formatting based on status
if [ "$status" = "Playing" ]; then
    if [ -n "$time_str" ]; then
        echo "$player_icon $dynamic $time_str$ws_info"
    else
        echo "$player_icon $dynamic$ws_info"
    fi
else
    # Paused - use italic (Pango markup)
    if [ -n "$time_str" ]; then
        echo "$status_icon <i>$dynamic</i> $time_str$ws_info"
    else
        echo "$status_icon <i>$dynamic</i>$ws_info"
    fi
fi
