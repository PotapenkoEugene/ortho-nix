#!/bin/bash
SESSION="notes"
SOCK="notes"
SCRIPT="$HOME/.config/home-manager/scripts/obsidian_daily_notes.lua"
TODAY_NOTE="$HOME/Orthidian/daily/$(date +%Y-%m-%d).md"
unset TMUX

if ! tmux -L "$SOCK" has-session -t "$SESSION" 2>/dev/null; then
    # No session: create with nvim, generate today's note
    tmux -L "$SOCK" new-session -d -s "$SESSION" -c "$HOME/Orthidian" \
        "nvim -c 'luafile $SCRIPT'"
elif [ ! -f "$TODAY_NOTE" ]; then
    # Session exists but no today's note: send keys to generate it
    tmux -L "$SOCK" send-keys -t "$SESSION" Escape
    tmux -L "$SOCK" send-keys -t "$SESSION" ":luafile $SCRIPT" Enter
fi

tmux -L "$SOCK" attach-session -t "$SESSION"
