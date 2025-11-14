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
    # For browsers and multi-window apps, try multiple strategies to find the right window
    matching_window=""
    
    # Strategy 1: Try to find window whose name contains the media title
    # (works when media is in the active tab)
    if [ -n "$title" ]; then
        matching_window=$(swaymsg -t get_tree | jq -r --arg pid "$player_pid" --arg title "$title" '
            .. | 
            select(.pid?) | 
            select(.pid == ($pid | tonumber)) | 
            select(.name? | contains($title)) | 
            .id
        ' 2>/dev/null | head -n1)
    fi
    
    # Strategy 2: If title matching failed, list ALL workspaces with this PID
    # (for multi-window apps where we can't determine which window is playing)
    if [ -z "$matching_window" ]; then
        # Get all unique workspaces that have windows with this PID
        workspace=$(swaymsg -t get_tree | jq -r --arg pid "$player_pid" '
            [.. | select(.type? == "workspace") | select(.. | select(.pid?) | .pid == ($pid | tonumber)) | .num // .name] | 
            unique | 
            join(",")
        ' 2>/dev/null)
        
        # If we got multiple workspaces or a single one, we're done
        # Skip the rest of the logic
        if [ -n "$workspace" ]; then
            matching_window="skip"
        fi
    fi
    
    # Find which workspace contains the matched window (only if we matched by title)
    if [ -n "$matching_window" ] && [ "$matching_window" != "skip" ]; then
        workspace=$(swaymsg -t get_tree | jq -r --arg wid "$matching_window" '
            .. | 
            select(.type? == "workspace") | 
            select(.. | .id? == ($wid | tonumber)) | 
            .num // .name
        ' 2>/dev/null | head -n1)
    fi
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
