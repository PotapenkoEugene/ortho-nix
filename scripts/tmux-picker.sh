#!/usr/bin/env bash
#============================================================================
# Tmux Picker — unified fuzzy-select for local + mac-studio tmux sessions
#
# Runs in a kitty overlay (--type=overlay), bound to Ctrl+Shift+M.
# Shows all sessions from both hosts, sorted by usage frequency.
#
# Display format:
#   [mac] ADAPTOGENE   ← mac-studio session (opens/focuses mac_* tab)
#   [loc] base         ← local linux session (focuses bare tab or spawns one)
#
# Frequency file: ~/.local/share/tmux-picker-freq
#   Each line: COUNT<TAB>DISPLAY_LINE   (sorted desc on write, re-read on open)
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"
FREQ_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/tmux-picker-freq"
RAW="/tmp/tmux-picker-$$.raw"
trap 'rm -f "$RAW"' EXIT

# Gather sessions
{
    tmux ls -F "[loc] #{session_name}" 2>/dev/null || true
    ssh -o BatchMode=yes -o ConnectTimeout=5 mac-studio \
        'tmux ls -F "[mac] #{session_name}"' 2>/dev/null || true
} > "$RAW"

[ ! -s "$RAW" ] && { echo "no tmux sessions found"; sleep 2; exit 1; }

# Sort by usage frequency; unknown entries get 0 and appear last
sorted=$(awk -v freq_file="$FREQ_FILE" '
BEGIN {
    while ((getline line < freq_file) > 0)
        if (split(line, a, "\t") == 2) freq[a[2]] = int(a[1])
    close(freq_file)
}
{ count = ($0 in freq) ? freq[$0] : 0; printf "%d\t%s\n", count, $0 }
' "$RAW" | sort -t$'\t' -k1 -rn | cut -f2-)

# Fuzzy pick
selected=$(echo "$sorted" | tv) || exit 0
[ -z "$selected" ] && exit 0

# Parse: "[mac] ADAPTOGENE" → host="mac", sess="ADAPTOGENE"
host="${selected:1:3}"   # chars 1-3 inside brackets: "mac" or "loc"
sess="${selected:6}"     # everything after "[xxx] "

# Update frequency counter
mkdir -p "$(dirname "$FREQ_FILE")"
declare -A freq
if [ -f "$FREQ_FILE" ]; then
    while IFS=$'\t' read -r cnt key; do
        freq["$key"]=$cnt
    done < "$FREQ_FILE"
fi
freq["$selected"]=$(( ${freq["$selected"]:-0} + 1 ))
{
    for k in "${!freq[@]}"; do
        printf '%s\t%s\n' "${freq[$k]}" "$k"
    done
} | sort -t$'\t' -k1 -rn > "$FREQ_FILE"

# Open or focus tab based on host
if [ "$host" = "mac" ]; then
    tab_title="mac_$sess"
    tab_id=$(kitten @ --to "$SOCK" ls 2>/dev/null \
        | jq -r --arg t "$tab_title" '.[].tabs[] | select(.title == $t) | .id' \
        | head -1)
    if [ -n "$tab_id" ]; then
        kitten @ --to "$SOCK" focus-tab --match "id:$tab_id"
    else
        kitten @ --to "$SOCK" launch \
            --type=tab --tab-title "$tab_title" mac-attach.sh "$sess"
    fi
else
    tab_id=$(kitten @ --to "$SOCK" ls 2>/dev/null \
        | jq -r --arg t "$sess" '.[].tabs[] | select(.title == $t) | .id' \
        | head -1)
    if [ -n "$tab_id" ]; then
        kitten @ --to "$SOCK" focus-tab --match "id:$tab_id"
    else
        kitten @ --to "$SOCK" launch \
            --type=tab --tab-title "$sess" kitty-tab-launch.sh "$sess"
    fi
fi
