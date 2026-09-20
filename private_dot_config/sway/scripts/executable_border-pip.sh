#!/bin/bash
# Sway hands decoration control to floating clients that request CSD
# (xdg_decoration.c: `if (floating && client_mode) mode = client_mode`), so
# view_update_csd_from_client() clobbers any border set by for_window criteria
# at map time. Re-issuing the border once the window has settled sticks.
sleep 0.2
swaymsg '[title="^(Picture-in-Picture)$"] border pixel 2' >/dev/null
