#!/usr/bin/env bash

# Get the active Bluetooth audio profile
profile=$(pactl list cards | grep -A 40 "bluez_card" | grep "Active Profile:" | head -n1 | sed 's/.*Active Profile: //')

if [ -n "$profile" ]; then
    case "$profile" in
        a2dp-sink*)
            echo "A2DP "
            ;;
        headset-head-unit*)
            echo "HSP/HFP "
            ;;
        off)
            echo ""
            ;;
        *)
            echo "$profile"
            ;;
    esac
else
    # Always output something to maintain consistent width
    echo ""
fi
