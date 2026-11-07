#!/bin/bash

# chezmoi cannot produce swaync's generated palette.css, and a fresh
# gtk-3.0/settings.ini starts out dark. Running the hooks once for whatever mode
# darkman reports fills both in on a new machine. It is run_onchange rather than
# run_after because re-running the hooks on every apply redraws the wallpaper
# and restyles every app; settings.ini is a modify template that keeps the live
# theme keys, so later applies no longer undo darkman.

if ! command -v darkman &>/dev/null; then
    exit 0
fi

mode=$(darkman get 2>/dev/null)

# "null" means darkman has no location yet and no mode to restore.
if [ "$mode" != "dark" ] && [ "$mode" != "light" ]; then
    exit 0
fi

for hook in "$HOME/.local/share/$mode-mode.d"/*; do
    [ -x "$hook" ] && "$hook"
done
