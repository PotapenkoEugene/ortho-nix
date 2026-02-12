#!/usr/bin/env bash
# Claude Code Status Line - Powerline Design
# Shows: username │ directory │ git status │ model │ vim mode │ agent │ tokens

input=$(cat)

# Extract data from JSON
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
agent=$(echo "$input" | jq -r '.agent.name // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# Track compaction count per session
# Detect compaction: used_percentage drops by >20 points between refreshes
STATE_FILE="/tmp/claude-statusline-${session_id}"
compact_count=0
prev_pct=0
if [ -n "$session_id" ] && [ -f "$STATE_FILE" ]; then
    read -r prev_pct compact_count < "$STATE_FILE" 2>/dev/null
    compact_count=${compact_count:-0}
    prev_pct=${prev_pct:-0}
    # If usage dropped significantly, a compaction happened
    if [ "$prev_pct" -gt 0 ] && [ $(( prev_pct - used_pct )) -gt 20 ]; then
        compact_count=$(( compact_count + 1 ))
    fi
fi
if [ -n "$session_id" ]; then
    echo "$used_pct $compact_count" > "$STATE_FILE"
fi

# Get username only
user=$(whoami)

# Get short directory path (replace home with ~)
short_dir="${cwd/#$HOME/\~}"

# Get git branch and status (skip locks for performance)
git_branch=""
git_status=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)

    if [ -n "$git_branch" ]; then
        # Check for various git states
        has_staged=$(git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null; echo $?)
        has_unstaged=$(git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null; echo $?)
        has_untracked=$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | grep -q .; echo $?)

        # Build git status indicator
        if [ "$has_staged" -ne 0 ]; then
            git_status="●"  # Staged changes
        elif [ "$has_unstaged" -ne 0 ]; then
            git_status="✗"  # Dirty (modified)
        elif [ "$has_untracked" -eq 0 ]; then
            git_status="…"  # Untracked files
        else
            git_status="✓"  # Clean
        fi
    fi
fi

# Powerline-style design with background colors
# Using 256-color palette for backgrounds and bright foreground text

# Background colors (dark, muted tones)
BG_USER='\033[48;5;24m'      # Dark blue background
BG_DIR='\033[48;5;22m'       # Dark green background
BG_GIT_CLEAN='\033[48;5;28m' # Green background for clean
BG_GIT_DIRTY='\033[48;5;3m'  # Yellow/orange background for dirty
BG_GIT_STAGED='\033[48;5;53m' # Purple background for staged
BG_MODEL='\033[48;5;25m'     # Blue background
BG_VIM='\033[48;5;58m'       # Brown/orange background
BG_AGENT='\033[48;5;88m'     # Dark red background
BG_CTX_HIGH='\033[48;5;240m' # Dark gray (plenty of context)
BG_CTX_MED='\033[48;5;3m'    # Yellow (medium context)
BG_CTX_LOW='\033[48;5;1m'    # Red (low context)

# Foreground colors (bright, high contrast)
FG_BRIGHT='\033[97m'         # Bright white text
FG_BLACK='\033[30m'          # Black text (for yellow backgrounds)

C_RESET='\033[0m'

# Helper function to create a block with background
block() {
    local bg="$1"
    local fg="$2"
    local text="$3"
    printf "${bg}${fg} %s ${C_RESET}" "$text"
}

# Build status line
output=""

# Username block
output+="$(block "$BG_USER" "$FG_BRIGHT" "$user")"

# Directory block
output+="$(block "$BG_DIR" "$FG_BRIGHT" "$short_dir")"

# Git branch with status indicator
if [ -n "$git_branch" ]; then
    # Choose background color based on git status
    if [ "$git_status" = "●" ]; then
        git_bg="$BG_GIT_STAGED"
        git_fg="$FG_BRIGHT"
    elif [ "$git_status" = "✗" ] || [ "$git_status" = "…" ]; then
        git_bg="$BG_GIT_DIRTY"
        git_fg="$FG_BLACK"  # Black text on yellow background
    else
        git_bg="$BG_GIT_CLEAN"
        git_fg="$FG_BRIGHT"
    fi
    output+="$(block "$git_bg" "$git_fg" " $git_branch $git_status")"
fi

# Model name (shorten if needed)
short_model="${model/Claude /}"
output+="$(block "$BG_MODEL" "$FG_BRIGHT" "$short_model")"

# Output style if not default
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
    output+="$(block "$BG_MODEL" "$FG_BRIGHT" "$output_style")"
fi

# Vim mode if active
if [ -n "$vim_mode" ]; then
    output+="$(block "$BG_VIM" "$FG_BRIGHT" "[$vim_mode]")"
fi

# Agent if active
if [ -n "$agent" ]; then
    output+="$(block "$BG_AGENT" "$FG_BRIGHT" "$agent")"
fi

# Token usage (actual count + color by used percentage)
# Format token count as "123k"
format_tokens() {
    local t=$1
    if [ "$t" -ge 1000000 ]; then
        printf "%.1fM" "$(echo "$t / 1000000" | bc -l)"
    elif [ "$t" -ge 1000 ]; then
        printf "%dk" "$(( t / 1000 ))"
    else
        printf "%d" "$t"
    fi
}

# Derive current context usage from percentage (total_input/output are cumulative, not current)
current_tokens=$(( ctx_size * used_pct / 100 ))
tokens_display="$(format_tokens "$current_tokens")/$(format_tokens "$ctx_size")"

# Color based on used_percentage — thresholds adjusted for realistic compacting
# Compacting often starts ~80% so warn earlier
if (( $(echo "$used_pct > 75" | bc -l 2>/dev/null || echo 0) )); then
    ctx_bg="$BG_CTX_LOW"
    ctx_fg="$FG_BRIGHT"
    ctx_icon="▂"
elif (( $(echo "$used_pct > 50" | bc -l 2>/dev/null || echo 0) )); then
    ctx_bg="$BG_CTX_MED"
    ctx_fg="$FG_BLACK"
    ctx_icon="▄"
else
    ctx_bg="$BG_CTX_HIGH"
    ctx_fg="$FG_BRIGHT"
    ctx_icon="▆"
fi
output+="$(block "$ctx_bg" "$ctx_fg" "$ctx_icon $tokens_display")"

# Compaction counter with color gradient: green(0) → yellow(1-2) → red(3+)
BG_COMPACT_0='\033[48;5;22m'   # Dark green — fresh session
BG_COMPACT_1='\033[48;5;28m'   # Green — first compaction
BG_COMPACT_2='\033[48;5;3m'    # Yellow — getting long
BG_COMPACT_3='\033[48;5;1m'    # Red — consider new session
if [ "$compact_count" -ge 3 ]; then
    cmp_bg="$BG_COMPACT_3"; cmp_fg="$FG_BRIGHT"
elif [ "$compact_count" -ge 2 ]; then
    cmp_bg="$BG_COMPACT_2"; cmp_fg="$FG_BLACK"
elif [ "$compact_count" -ge 1 ]; then
    cmp_bg="$BG_COMPACT_1"; cmp_fg="$FG_BRIGHT"
else
    cmp_bg="$BG_COMPACT_0"; cmp_fg="$FG_BRIGHT"
fi
output+="$(block "$cmp_bg" "$cmp_fg" "⟳${compact_count}")"

printf '%s\n' "$output"
