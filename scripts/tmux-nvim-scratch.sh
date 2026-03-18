#!/usr/bin/env bash
# Opens tmux copy-mode selection in a temporary nvim buffer via popup.
# Called by: copy-pipe-and-cancel in tmux copy-mode-vi (V key)

TMPFILE="/tmp/scratch-$(date +%Y-%m-%d-%H%M%S).md"

# Read piped selection from stdin
cat > "$TMPFILE"

# Open nvim in a tmux popup with the scratch file
tmux display-popup -w 90% -h 85% -E "nvim '$TMPFILE'"
