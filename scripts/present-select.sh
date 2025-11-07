#!/bin/bash

# Present mode options
options="Mirror\nSet Output\nSet Region\nUnset Region\nSet Scaling\nToggle Freeze\nCustom"

# Show wofi menu and get selection
selected=$(echo -e "$options" | wofi --dmenu --prompt "Present Mode:")

# Execute corresponding wl-present command based on selection
case "$selected" in
    "Mirror")
        wl-present mirror
        ;;
    "Set Output")
        wl-present set-output
        ;;
    "Set Region")
        wl-present set-region
        ;;
    "Unset Region")
        wl-present unset-region
        ;;
    "Set Scaling")
        wl-present set-scaling
        ;;
    "Toggle Freeze")
        wl-present toggle-freeze
        ;;
    "Custom")
        wl-present custom
        ;;
esac