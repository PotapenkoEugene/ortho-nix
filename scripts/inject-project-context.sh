#!/usr/bin/env bash
# SessionStart hook: inject active Obsidian project file as additionalContext
# Reads "## Active Obsidian Project" from CLAUDE.md in the current project directory.
# Outputs JSON to stdout; exits 0 silently if no active project found.
set -euo pipefail

PROJECT_DIR="$(pwd)"

# Look for CLAUDE.md in .claude/ subdir first, then project root
CLAUDE_MD=""
for f in "$PROJECT_DIR/.claude/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"; do
    if [ -f "$f" ]; then
        CLAUDE_MD="$f"
        break
    fi
done

[ -z "$CLAUDE_MD" ] && exit 0

# Extract File: path from ## Active Obsidian Project section
PROJECT_FILE=$(awk '
    /^## Active Obsidian Project/ { found=1; next }
    found && /^## / { exit }
    found && /^- File:/ { sub(/^- File: /, ""); print; exit }
' "$CLAUDE_MD" | sed "s|~/|$HOME/|")

[ -z "$PROJECT_FILE" ] && exit 0
[ ! -f "$PROJECT_FILE" ] && exit 0

PROJECT_NAME=$(basename "$PROJECT_FILE" .md)
CONTENT=$(cat "$PROJECT_FILE")

# Build tidy summary of open objectives
SUMMARY=$(awk '
    function flush(    label) {
        if (!collecting) return
        label = length(obj) > 38 ? substr(obj, 1, 35) "..." : obj
        if (first_sub != "")
            printf "  %-38s → %s\n", label, first_sub
        else
            printf "  %s\n", label
        collecting = 0
    }
    /^## Objectives/ { in_obj=1; next }
    in_obj && /^## /  { flush(); in_obj=0; next }
    !in_obj { next }
    /^- \[[ !>]\]/ {
        flush()
        obj = $0; sub(/^- \[[ !>]\] /, "", obj)
        first_sub = ""; collecting = 1; next
    }
    /^- \[[xX~]\]/ { flush(); next }
    collecting && /^    - \[[ !>]\]/ {
        if (first_sub == "") {
            first_sub = $0
            sub(/^    - \[[ !>]\] /, "", first_sub)
            if (length(first_sub) > 48) first_sub = substr(first_sub, 1, 45) "..."
        }
        next
    }
    collecting && /^    / { next }
END { flush() }
' "$PROJECT_FILE")

# Show summary via notify-send (desktop notification) and tmux status bar
notify-send --urgency=low --expire-time=8000 \
    "Project: $PROJECT_NAME" "$SUMMARY" 2>/dev/null || true
tmux display-message -d 6000 "── $PROJECT_NAME ── session start" 2>/dev/null || true

jq -n \
    --arg name "$PROJECT_NAME" \
    --arg file "$PROJECT_FILE" \
    --arg content "$CONTENT" \
    '{
        hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: ("Active Obsidian project: " + $name + "\nFile: " + $file + "\n\n" + $content)
        }
    }'

exit 0
