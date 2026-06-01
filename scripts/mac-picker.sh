#!/usr/bin/env bash
#============================================================================
# Mac Picker — fuzzy-select a mac-studio tmux session and open/focus its tab
#
# Runs in a kitty overlay (--type=overlay). On selection:
#   - If mac_<S> tab exists: focus it
#   - Otherwise: open new tab titled mac_<S> running mac-attach.sh <S>
#
# Invoked via Ctrl+Shift+M keybinding in kitty (modules/terminal.nix).
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"

# Fetch live mac tmux sessions
sessions=$(ssh -o BatchMode=yes -o ConnectTimeout=10 mac-studio \
    'tmux ls -F "#{session_name}"' 2>/dev/null) || {
    echo "mac-studio unreachable"
    sleep 2
    exit 1
}

# Fuzzy pick with tv
name=$(echo "$sessions" | tv) || exit 0   # empty/cancelled → just close overlay
[ -z "$name" ] && exit 0

# Check if tab already open (focus) or open new tab
existing=$(kitten @ --to "$SOCK" ls 2>/dev/null | jq -r '.[].tabs[] | select(.title == "mac_'"$name"'") | .id' | head -1)
if [ -n "$existing" ]; then
    kitten @ --to "$SOCK" focus-tab --match "id:$existing"
else
    kitten @ --to "$SOCK" launch \
        --type=tab \
        --tab-title "mac_$name" \
        mac-attach.sh "$name"
fi
