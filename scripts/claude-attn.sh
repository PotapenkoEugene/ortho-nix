#!/usr/bin/env bash
# Claude Code attention indicator — set/clear tmux window recolor + kitty bell.
#
# Subcommands:
#   set           - red indicator (action required); derives window from $TMUX_PANE
#   done          - green indicator (task finished); derives window from $TMUX_PANE
#   clear         - clear any indicator; derives window from $TMUX_PANE
#   clear-done WIN_ID - clear green indicator only; WIN_ID passed by tmux hook
set -euo pipefail

action="${1:-}"

_clear_win() {
  local win="$1"
  tmux set-window-option -u -t "$win" @claude_attn              2>/dev/null || true
  tmux set-window-option -u -t "$win" window-status-style       2>/dev/null || true
  tmux set-window-option -u -t "$win" window-status-current-style 2>/dev/null || true
}

case "$action" in
  set|done|clear)
    [ -n "${TMUX_PANE:-}" ] || exit 0
    WIN=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null) || exit 0
    TTY=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null) || true
    case "$action" in
      set)
        tmux set-window-option -t "$WIN" @claude_attn action 2>/dev/null || true
        tmux set-window-option -t "$WIN" window-status-style        "bg=#f38ba8,fg=#11111b,bold" 2>/dev/null || true
        tmux set-window-option -t "$WIN" window-status-current-style "bg=#f38ba8,fg=#11111b,bold" 2>/dev/null || true
        [ -n "${TTY:-}" ] && printf '\a' > "$TTY" 2>/dev/null || true
        ;;
      done)
        tmux set-window-option -t "$WIN" @claude_attn done 2>/dev/null || true
        tmux set-window-option -t "$WIN" window-status-style        "bg=#a6e3a1,fg=#11111b,bold" 2>/dev/null || true
        tmux set-window-option -t "$WIN" window-status-current-style "bg=#a6e3a1,fg=#11111b,bold" 2>/dev/null || true
        ;;
      clear)
        _clear_win "$WIN"
        ;;
    esac
    ;;
  clear-done)
    # Called from tmux after-select-window hook; WIN_ID = #{window_id}
    TARGET="${2:-}"
    [ -n "$TARGET" ] || exit 0
    VAL=$(tmux show-window-options -vt "$TARGET" @claude_attn 2>/dev/null) || true
    [ "$VAL" = "done" ] && _clear_win "$TARGET" || true
    ;;
  *)
    echo "Usage: claude-attn.sh set|done|clear|clear-done WIN_ID" >&2
    exit 1
    ;;
esac
