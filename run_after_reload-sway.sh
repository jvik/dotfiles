#!/bin/bash

if [ -n "$SWAYSOCK" ] && command -v swaymsg &>/dev/null; then
    swaymsg reload
fi
