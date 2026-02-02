#!/usr/bin/env bash
# Claude Code Status Line - Powerline Design
# Shows: username │ directory │ git status │ model │ vim mode │ agent │ context usage

input=$(cat)

# Extract data from JSON
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
agent=$(echo "$input" | jq -r '.agent.name // empty')

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

# Context remaining (with visual indicator)
if [ -n "$remaining" ]; then
    # Choose background and icon based on remaining percentage
    if (( $(echo "$remaining < 20" | bc -l 2>/dev/null || echo 0) )); then
        ctx_bg="$BG_CTX_LOW"
        ctx_fg="$FG_BRIGHT"
        ctx_icon="▂"
    elif (( $(echo "$remaining < 50" | bc -l 2>/dev/null || echo 0) )); then
        ctx_bg="$BG_CTX_MED"
        ctx_fg="$FG_BLACK"
        ctx_icon="▄"
    else
        ctx_bg="$BG_CTX_HIGH"
        ctx_fg="$FG_BRIGHT"
        ctx_icon="▆"
    fi
    output+="$(block "$ctx_bg" "$ctx_fg" "$ctx_icon $remaining%")"
fi

printf '%s\n' "$output"
