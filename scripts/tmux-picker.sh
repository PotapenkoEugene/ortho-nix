#!/usr/bin/env bash
#============================================================================
# Tmux Picker — unified fuzzy-select for local + mac-studio tmux sessions
#
# Opens as a new kitty tab (--type=tab), NOT an overlay.
# On selection:
#   - Tab already exists → focus it, exit (this tab closes)
#   - No tab yet → exec the session in THIS tab (tab transforms, no kitten @ launch)
#
# Debug log: /tmp/tmux-picker.log (check if things go wrong)
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"
FREQ_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/tmux-picker-freq"
LOG="/tmp/tmux-picker.log"
RAW="/tmp/tmux-picker-$$.raw"
trap 'rm -f "$RAW"' EXIT

# Redirect stderr to log for diagnostics
exec 2>>"$LOG"
echo "=== $(date) ===" >> "$LOG"

# Gather sessions
{
    tmux ls -F "[loc] #{session_name}" 2>/dev/null || true
    ssh -o BatchMode=yes -o ConnectTimeout=5 mac-studio \
        'tmux ls -F "[mac] #{session_name}"' 2>/dev/null || true
} > "$RAW"

if [ ! -s "$RAW" ]; then
    echo "no sessions found" >> "$LOG"
    echo "no tmux sessions found"
    sleep 2
    exit 1
fi

# Sort by usage frequency
sorted=$(awk -v freq_file="$FREQ_FILE" '
BEGIN {
    while ((getline line < freq_file) > 0)
        if (split(line, a, "\t") == 2) freq[a[2]] = int(a[1])
    close(freq_file)
}
{ count = ($0 in freq) ? freq[$0] : 0; printf "%d\t%s\n", count, $0 }
' "$RAW" | sort -t$'\t' -k1 -rn | cut -f2-)

echo "sessions: $sorted" >> "$LOG"

# Fuzzy pick
selected=$(echo "$sorted" | tv --ui-scale 70 --no-preview)
echo "selected: '$selected'" >> "$LOG"
[ -z "$selected" ] && exit 0

# Parse "[mac] ADAPTOGENE" → host, sess
host="${selected:1:3}"
sess="${selected:6}"
echo "host='$host' sess='$sess'" >> "$LOG"

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
    if kitten @ --to "$SOCK" focus-tab --match "title:$tab_title" 2>>"$LOG"; then
        echo "focused existing: $tab_title" >> "$LOG"
        # exit closes this picker tab; focus already set to target
        exit 0
    else
        echo "transforming picker tab into: $tab_title" >> "$LOG"
        # Set title via OSC sequence, then replace this process with the transport
        printf '\033]2;%s\007' "$tab_title"
        exec mac-attach.sh "$sess"
    fi
else
    if kitten @ --to "$SOCK" focus-tab --match "title:$sess" 2>>"$LOG"; then
        echo "focused existing: $sess" >> "$LOG"
        exit 0
    else
        echo "transforming picker tab into: $sess" >> "$LOG"
        printf '\033]2;%s\007' "$sess"
        exec kitty-tab-launch.sh "$sess"
    fi
fi
