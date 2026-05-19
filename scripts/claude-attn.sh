#!/usr/bin/env bash
# Claude Code attention indicator — set/clear tmux window recolor + kitty bell.
# Called by claude-notify.sh (set) and UserPromptSubmit/Stop hooks (clear).
set -euo pipefail

action="${1:-}"
[ -n "${TMUX_PANE:-}" ] || exit 0

WIN=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null) || exit 0
TTY=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null) || true

case "$action" in
  set)
    tmux set-window-option -t "$WIN" @claude_attn 1 2>/dev/null || true
    tmux set-window-option -t "$WIN" window-status-style        "bg=#f38ba8,fg=#11111b,bold" 2>/dev/null || true
    tmux set-window-option -t "$WIN" window-status-current-style "bg=#f38ba8,fg=#11111b,bold" 2>/dev/null || true
    [ -n "${TTY:-}" ] && printf '\a' > "$TTY" 2>/dev/null || true
    ;;
  clear)
    tmux set-window-option -u -t "$WIN" @claude_attn              2>/dev/null || true
    tmux set-window-option -u -t "$WIN" window-status-style       2>/dev/null || true
    tmux set-window-option -u -t "$WIN" window-status-current-style 2>/dev/null || true
    ;;
  *)
    echo "Usage: claude-attn.sh set|clear" >&2
    exit 1
    ;;
esac
