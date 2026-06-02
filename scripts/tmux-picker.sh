#!/usr/bin/env bash
#============================================================================
# Tmux Picker — unified fuzzy-select for local + mac-studio tmux sessions
#
# Opens as a new kitty tab (--type=tab).
# On selection:
#   - Tab already exists → focus it, exit (this tab closes)
#   - No tab yet → exec the session in THIS tab (tab transforms)
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"
FREQ_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/tmux-picker-freq"
RAW="/tmp/tmux-picker-$$.raw"
MAC_TMP="/tmp/tmux-picker-mac-$$"
trap 'rm -f "$RAW" "$MAC_TMP"' EXIT

# Start SSH in background — don't block tv startup
ssh -o BatchMode=yes -o ConnectTimeout=3 mac-studio \
    'tmux ls -F "[mac] #{session_name}"' > "$MAC_TMP" 2>/dev/null &
SSH_PID=$!

# Local sessions are instant
tmux ls -F "[loc] #{session_name}" 2>/dev/null > "$RAW" || true

# Wait for ssh (max 3s), append mac sessions
wait "$SSH_PID" 2>/dev/null || true
cat "$MAC_TMP" >> "$RAW" 2>/dev/null || true

[ ! -s "$RAW" ] && { echo "no tmux sessions found"; sleep 2; exit 1; }

# Sort by usage frequency
sorted=$(awk -v freq_file="$FREQ_FILE" '
BEGIN {
    while ((getline line < freq_file) > 0)
        if (split(line, a, "\t") == 2) freq[a[2]] = int(a[1])
    close(freq_file)
}
{ count = ($0 in freq) ? freq[$0] : 0; printf "%d\t%s\n", count, $0 }
' "$RAW" | sort -t$'\t' -k1 -rn | cut -f2-)

# Fuzzy pick — tv uses stderr for TUI; do NOT redirect stderr globally
selected=$(echo "$sorted" | tv --ui-scale 70 --no-preview)
[ -z "$selected" ] && exit 0

# Parse "[mac] ADAPTOGENE" → host, sess
host="${selected:1:3}"
sess="${selected:6}"

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

# Open or focus
if [ "$host" = "mac" ]; then
    tab_title="mac_$sess"
    if kitten @ --to "$SOCK" focus-tab --match "title:$tab_title" 2>/dev/null; then
        exit 0
    fi
    printf '\033]2;%s\007' "$tab_title"
    exec mac-attach.sh "$sess"
else
    if kitten @ --to "$SOCK" focus-tab --match "title:$sess" 2>/dev/null; then
        exit 0
    fi
    printf '\033]2;%s\007' "$sess"
    exec kitty-tab-launch.sh "$sess"
fi
