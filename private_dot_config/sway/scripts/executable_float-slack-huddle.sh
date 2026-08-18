#!/bin/bash
# Slack sets the "Huddle Preview" / "Huddle: ..." window title asynchronously
# after the window is mapped, so for_window's title criteria races and misses
# it. Slack also enforces its own minimum content height regardless of any
# resize we request, so a percentage-based "move position" computed from the
# requested height can push the window below the bottom of the screen once
# Slack expands it. Float+resize first, let it settle, then anchor
# bottom-right using the window's *actual* rendered size.
sleep 0.3
swaymsg '[app_id="com.slack.Slack" title="Huddle"] floating enable, sticky enable, resize set width 20 ppt' >/dev/null
sleep 0.2

con=$(swaymsg -t get_tree | jq -c '
  first(.. | objects | select(.app_id? == "com.slack.Slack") | select((.name? // "") | test("Huddle")))
')
[ -z "$con" ] || [ "$con" = "null" ] && exit 0

con_id=$(jq -r '.id' <<<"$con")
w=$(jq -r '.rect.width' <<<"$con")
h=$(jq -r '.rect.height' <<<"$con")
cx=$(jq -r '.rect.x' <<<"$con")
cy=$(jq -r '.rect.y' <<<"$con")

out=$(swaymsg -t get_outputs | jq -c --argjson x "$cx" --argjson y "$cy" '
  first(.[] | select(.rect.x <= $x and $x < (.rect.x + .rect.width) and .rect.y <= $y and $y < (.rect.y + .rect.height)))
')
[ -z "$out" ] || [ "$out" = "null" ] && exit 0

ox=$(jq -r '.rect.x' <<<"$out")
oy=$(jq -r '.rect.y' <<<"$out")
ow=$(jq -r '.rect.width' <<<"$out")
oh=$(jq -r '.rect.height' <<<"$out")

margin_x=40
margin_y=60
target_x=$(( ox + ow - w - margin_x ))
target_y=$(( oy + oh - h - margin_y ))

swaymsg "[con_id=$con_id] move absolute position ${target_x} px ${target_y} px" >/dev/null
