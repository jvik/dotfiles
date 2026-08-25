#!/usr/bin/env bash
# Re-apply the kanshi output layout after a sway reload.
#
# `swaymsg reload` resets output configuration to what sway's own config file
# specifies, discarding kanshi's positions and modes -- after a reload the
# laptop panel jumps back to 0,0. kanshi has no reload signal and Debian ships
# no kanshictl, so restarting the service is the only way to restore it. This
# is also what picks up kanshi config edits: run_after_reload-sway.sh reloads
# sway after a chezmoi apply, which lands here.
#
# The delay is the whole point. Restarting kanshi *while* sway is still
# processing the reload is a DRM modeset landing on a compositor mid-rebuild,
# and that is what turned mod+Shift+c into a black screen. Deferring it until
# the reload has settled makes it an ordinary modeset, the same as a hotplug.

set -uo pipefail

# Non-blocking: if a re-apply is already pending, that one will pick up the
# final state anyway. Overlapping reloads must not stack modesets.
exec 9>"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/reapply-kanshi.lock"
flock -n 9 || exit 0

sleep "${REAPPLY_KANSHI_DELAY:-1.5}"
systemctl --user restart kanshi.service
