#!/bin/bash

# chezmoi apply rewrites gtk-3.0/settings.ini back to its checked-in (dark)
# values, and it cannot produce swaync's generated palette.css at all. Re-running
# the hooks for whatever mode darkman currently reports fixes both, so applying
# dotfiles in the middle of the day doesn't leave the desktop half-dark.

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
