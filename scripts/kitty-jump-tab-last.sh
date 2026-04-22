#!/usr/bin/env bash
# Jump to the rightmost (last) Kitty tab.
set -u

if [ -z "${KITTY_LISTEN_ON:-}" ]; then
    sock=$(ls /tmp/kitty-main-* 2>/dev/null | head -1)
    [ -n "$sock" ] && export KITTY_LISTEN_ON="unix:$sock"
fi

last_idx=$(kitten @ ls | jq -r '.[] | select(.is_focused) | (.tabs | length) - 1')
[ -z "$last_idx" ] && exit 0
kitten @ focus-tab --match "index:$last_idx"
