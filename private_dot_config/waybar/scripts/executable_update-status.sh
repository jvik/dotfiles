#!/usr/bin/env bash
# Streams the summary written by scripts/update-check.sh to waybar.
#
# The module has no `interval`: waybar reads a JSON object per line for as long
# as this runs, so watching the summary with inotify means the badge changes the
# moment a check finishes -- from the daily timer, the right-click refresh, or
# the topgrade run behind the left click -- instead of up to five minutes later.
# If inotifywait is missing the loop falls through and waybar's
# `restart-interval` turns this back into a cheap poll.
summary="$HOME/.cache/update-check/summary.json"
mkdir -p "$(dirname "$summary")"

render() {
    if [ ! -f "$summary" ]; then
        printf '{"text": "", "tooltip": "No update check has run yet"}\n'
        return
    fi

    total=$(jq '(.dnf // 0) + (.apt // 0) + (.flatpak // 0)' "$summary")
    checked_at=$(jq -r '.checked_at' "$summary")

    if [ "$total" -gt 0 ]; then
        printf '{"text": "󰚰 %s", "class": "pending", "tooltip": "%s update(s) available\\nLast checked: %s\\nClick to update"}\n' "$total" "$total" "$checked_at"
    else
        printf '{"text": "󰚰", "class": "", "tooltip": "System up to date\\nLast checked: %s"}\n' "$checked_at"
    fi
}

render

# Watch the directory, not the file: update-check.sh replaces the summary via
# `jq ... > "$SUMMARY"` rather than appending, so a watch on the inode alone
# would miss a recreated file.
while inotifywait -qq -e close_write,create,moved_to "$(dirname "$summary")" 2>/dev/null; do
    render
done
