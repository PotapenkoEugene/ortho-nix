#!/usr/bin/env bash
#============================================================================
# Mac Tabs — one-key restore of all mac-studio tmux sessions as kitty tabs
#
# Bound to Ctrl+Shift+M in kitty (modules/terminal.nix).
# Uses kitty remote control (allow_remote_control socket-only, unix:/tmp/kitty-main).
#
# Naming contract:
#   mac_<S>  ->  kitty tab title  (set by this script)
#   <S>      ->  mac tmux session (stripped of mac_ prefix)
#   bare <S> ->  local tmux tab   (untouched)
#
# Re-press is safe: tabs with title mac_<S> already open are skipped (dedup).
# Random-named tabs are never touched.
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"

# Fetch live mac tmux sessions
sessions=$(ssh -o BatchMode=yes -o ConnectTimeout=10 mac-studio \
    'tmux ls -F "#{session_name}"' 2>/dev/null) || {
    notify-send -u critical "mac-tabs" "mac-studio unreachable" 2>/dev/null || true
    echo "mac-studio unreachable" >&2
    exit 1
}

# Current kitty tab titles (for dedup)
existing=$(kitten @ --to "$SOCK" ls 2>/dev/null | jq -r '.[].tabs[].title' 2>/dev/null || true)

opened=0
while IFS= read -r name; do
    [ -z "$name" ] && continue
    # Skip tabs already open (idempotent re-press)
    if grep -qxF "mac_$name" <<<"$existing"; then
        continue
    fi
    kitten @ --to "$SOCK" launch \
        --type=tab \
        --tab-title "mac_$name" \
        mac-attach.sh "$name"
    opened=$((opened + 1))
done <<< "$sessions"

[ "$opened" -eq 0 ] && notify-send "mac-tabs" "all mac sessions already open" 2>/dev/null || true
