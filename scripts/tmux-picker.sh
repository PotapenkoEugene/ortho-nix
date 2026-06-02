#!/usr/bin/env bash
#============================================================================
# Tmux Picker — unified fuzzy-select for local + mac-studio tmux sessions
#
# Opens as a new kitty tab (--type=tab).
# On selection:
#   - Tab already exists → focus it, exit (this tab closes)
#   - No tab yet → exec the session in THIS tab (tab transforms)
#
# Each entry shows a recency bucket: [Now]/[Today]/[Week]/[Month]/[Older]
# color-coded with ANSI. Sorted by usage frequency (key = host:name).
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"
FREQ_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/tmux-picker-freq"
RAW="/tmp/tmux-picker-$$.raw"
MAC_TMP="/tmp/tmux-picker-mac-$$"
trap 'rm -f "$RAW" "$MAC_TMP"' EXIT

# Emit: host<TAB>attached<TAB>last_attached<TAB>name
# $'...' quoting produces actual tab chars — tmux does NOT interpret \t in -F strings
tmux ls -F $'loc\t#{session_attached}\t#{session_last_attached}\t#{session_name}' 2>/dev/null > "$RAW" || true

# Mac sessions via SSH — \$'...' passes $'...' to the remote shell for actual tab expansion
ssh -o BatchMode=yes -o ConnectTimeout=3 mac-studio \
    "tmux ls -F \$'mac\t#{session_attached}\t#{session_last_attached}\t#{session_name}'" \
    > "$MAC_TMP" 2>/dev/null &
SSH_PID=$!

wait "$SSH_PID" 2>/dev/null || true
cat "$MAC_TMP" >> "$RAW" 2>/dev/null || true

[ ! -s "$RAW" ] && { echo "no tmux sessions found"; sleep 2; exit 1; }

NOW=$(date +%s)

# Annotate with recency bucket + sort by usage frequency.
# Freq key = host:name (stable — survives label/color changes).
# Display line = <color>[Bucket]<reset>  [host]  name
sorted=$(awk -F'\t' -v now="$NOW" -v freq_file="$FREQ_FILE" '
BEGIN {
    while ((getline line < freq_file) > 0)
        if (split(line, a, "\t") == 2) freq[a[2]] = int(a[1])
    close(freq_file)
    c_now   = "\033[1;32m"
    c_today = "\033[36m"
    c_week  = "\033[34m"
    c_month = "\033[33m"
    c_older = "\033[90m"
    c_reset = "\033[0m"
}
{
    host = $1; attached = $2 + 0; last = $3 + 0; name = $4
    if (attached > 0) {
        color = c_now;   bucket = "[Now]"
    } else {
        delta = now - last
        if (last == 0 || delta >= 2592000) { color = c_older; bucket = "[Older]"  }
        else if (delta >= 604800)          { color = c_month; bucket = "[Month]"  }
        else if (delta >= 86400)           { color = c_week;  bucket = "[Week]"   }
        else                               { color = c_today; bucket = "[Today]"  }
    }
    key  = host ":" name
    cnt  = (key in freq) ? freq[key] : 0
    disp = color bucket c_reset "  [" host "]  " name
    printf "%d\t%s\n", cnt, disp
}
' "$RAW" | sort -t$'\t' -k1 -rn | cut -f2-)

# Fuzzy pick — tv --ansi renders ANSI escape codes from stdin
selected=$(echo "$sorted" | tv --ansi --ui-scale 70 --no-preview)
[ -z "$selected" ] && exit 0

# Parse selection: strip ANSI codes, then fields are: [Bucket]  [host]  name
clean=$(printf '%s' "$selected" | sed 's/\x1b\[[0-9;]*m//g')
# $1=[Bucket]  $2=[loc]/[mac]  $3..NF=session_name
host_tag=$(echo "$clean" | awk '{print $2}')
sess=$(echo "$clean" | awk '{for(i=3;i<=NF;i++) printf "%s%s",$i,(i<NF?" ":""); print ""}')
host="${host_tag:1:3}"   # strip brackets: "[loc]" → "loc", "[mac]" → "mac"

# Update frequency counter (key = host:name)
stable_key="${host}:${sess}"
mkdir -p "$(dirname "$FREQ_FILE")"
declare -A freq
if [ -f "$FREQ_FILE" ]; then
    while IFS=$'\t' read -r cnt key; do
        freq["$key"]=$cnt
    done < "$FREQ_FILE"
fi
freq["$stable_key"]=$(( ${freq["$stable_key"]:-0} + 1 ))
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
