#!/usr/bin/env bash
# Snap the focused Kitty tab to the leftmost position.
set -u

if [ -z "${KITTY_LISTEN_ON:-}" ]; then
    sock=$(ls /tmp/kitty-main-* 2>/dev/null | head -1)
    [ -n "$sock" ] && export KITTY_LISTEN_ON="unix:$sock"
fi

exec 200>"/tmp/kitty-move-tab-$(id -u).lock"
flock -n 200 || exit 0

read_state() {
    kitten @ ls | jq -r '
      .[] | select(.is_focused) | .tabs as $t |
      "\(($t | length))\t\([$t[] | .is_focused] | index(true))"
    '
}

prev_idx=-1
cap=40
while [ "$cap" -gt 0 ]; do
    IFS=$'\t' read -r _total idx < <(read_state)
    [ -z "${idx:-}" ] && break
    if [ "$idx" -le 0 ] || [ "$idx" = "$prev_idx" ]; then
        break
    fi
    prev_idx=$idx
    kitten @ action move_tab_backward
    cap=$((cap - 1))
done
