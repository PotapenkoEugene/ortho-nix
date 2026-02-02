#!/usr/bin/env bash
# Claude Code Status Line
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

# Color scheme (using ANSI codes that work well in dimmed terminal)
# Colors are chosen to be distinct and readable
C_USER='\033[96m'      # Bright cyan for username
C_DIR='\033[92m'       # Bright green for directory
C_GIT_CLEAN='\033[32m' # Green for clean repo
C_GIT_DIRTY='\033[33m' # Yellow for dirty repo
C_GIT_STAGED='\033[35m' # Magenta for staged changes
C_MODEL='\033[94m'     # Bright blue for model
C_VIM='\033[93m'       # Bright yellow for vim mode
C_AGENT='\033[91m'     # Bright red for agent
C_CTX='\033[90m'       # Gray for context
C_SEP='\033[2;37m'     # Dim white for separators
C_RESET='\033[0m'

# Powerline separator
SEP=" $(printf "$C_SEP")│$(printf "$C_RESET") "

# Build status line parts
status_parts=()

# Username
status_parts+=("$(printf "${C_USER}%s${C_RESET}" "$user")")

# Directory
status_parts+=("$(printf "${C_DIR}%s${C_RESET}" "$short_dir")")

# Git branch with status indicator
if [ -n "$git_branch" ]; then
    # Choose color based on git status
    if [ "$git_status" = "●" ]; then
        git_color="$C_GIT_STAGED"
    elif [ "$git_status" = "✗" ] || [ "$git_status" = "…" ]; then
        git_color="$C_GIT_DIRTY"
    else
        git_color="$C_GIT_CLEAN"
    fi
    status_parts+=("$(printf "${git_color} %s ${git_status}${C_RESET}" "$git_branch")")
fi

# Model name (shorten if needed)
short_model="${model/Claude /}"
status_parts+=("$(printf "${C_MODEL}%s${C_RESET}" "$short_model")")

# Output style if not default
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
    status_parts+=("$(printf "${C_MODEL}%s${C_RESET}" "$output_style")")
fi

# Vim mode if active
if [ -n "$vim_mode" ]; then
    status_parts+=("$(printf "${C_VIM}[%s]${C_RESET}" "$vim_mode")")
fi

# Agent if active
if [ -n "$agent" ]; then
    status_parts+=("$(printf "${C_AGENT}%s${C_RESET}" "$agent")")
fi

# Context remaining (with indicator)
if [ -n "$remaining" ]; then
    # Color code based on remaining percentage
    if (( $(echo "$remaining < 20" | bc -l 2>/dev/null || echo 0) )); then
        ctx_color="${C_AGENT}"  # Red when low
        ctx_icon="▂"
    elif (( $(echo "$remaining < 50" | bc -l 2>/dev/null || echo 0) )); then
        ctx_color="${C_GIT_DIRTY}"  # Yellow when medium
        ctx_icon="▄"
    else
        ctx_color="${C_CTX}"  # Gray when plenty
        ctx_icon="▆"
    fi
    status_parts+=("$(printf "${ctx_color}%s %s%%${C_RESET}" "$ctx_icon" "$remaining")")
fi

# Join with separator
printf '%s' "${status_parts[0]}"
for part in "${status_parts[@]:1}"; do
    printf '%s%s' "$SEP" "$part"
done
printf '\n'
