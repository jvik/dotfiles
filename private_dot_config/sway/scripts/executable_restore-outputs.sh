#!/bin/sh
# Bring every output back after a DPMS/power-off.
#
# The internal panel cannot always be re-added to a live DRM config while the
# ultrawide external is running near its top mode; sway logs "Search for valid
# config failed" and eDP-1 stays dark until the external is unplugged. Pinning
# a lower refresh in the kanshi profile avoids that, but escalate here so a
# failed modeset can never leave a black panel.

set -u

stuck() {
    swaymsg -t get_outputs \
        | jq -e '.[] | select(.active and (.power | not))' >/dev/null 2>&1
}

swaymsg "output * power on" >/dev/null 2>&1
sleep 0.5
stuck || exit 0

# Re-apply the kanshi profile: recomputes the whole output set in one commit.
systemctl --user restart kanshi.service
sleep 1
stuck || exit 0

# Last resort: drop the external and re-add it, which is what unplugging does.
ext=$(swaymsg -t get_outputs | jq -r '
    [.[] | select(.active and ((.name | test("^eDP")) | not))]
    | first // empty
    | .name')
[ -n "$ext" ] || exit 0
swaymsg "output $ext disable" >/dev/null 2>&1
swaymsg "output * power on" >/dev/null 2>&1
systemctl --user restart kanshi.service
