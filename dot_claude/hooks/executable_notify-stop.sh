#!/bin/bash
swaymsg -t get_tree | python3 -c "
import sys, json
def find_focused(n):
    if n.get('focused') and 'wezterm' in n.get('app_id', '').lower():
        open('/tmp/claude-wez-con', 'w').write(str(n['id']) + '\n' + str(n.get('pid', '')))
        return
    for c in n.get('nodes', []) + n.get('floating_nodes', []):
        find_focused(c)
find_focused(json.load(sys.stdin))
" 2>/dev/null
notify-send --app-name="Claude Code" -i dialog-information -t 10000 \
    --action=default=Show \
    "Claude Code" "Task complete" >/dev/null 2>&1 &
