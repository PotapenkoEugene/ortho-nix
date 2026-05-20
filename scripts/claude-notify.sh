#!/usr/bin/env bash
# Claude Code notification hook handler.
# Cross-platform: always emits Kitty OSC 99 desktop notification + BEL to the
# controlling TTY.  On Linux also plays peon sound + fires notify-send.
# Over SSH, OSC 99 travels through tmux allow-passthrough → Kitty on the local
# machine → native libnotify popup.  BEL rings Kitty's audible bell locally.
QUEUE="/tmp/claude-popup-queue"
LOCK="/tmp/claude-popup.lock"

# Get Claude's pane identity (inherited from Claude Code's environment)
PANE="${TMUX_PANE}"
SESSION=$(tmux display-message -p -t "$PANE" '#{session_name}' 2>/dev/null) || true
[ -z "$PANE" ] && exit 0

# Mark this tmux window as needing attention (recolors window-status + rings kitty bell)
"$(dirname "$0")"/claude-attn.sh set || true

# Add to queue
echo "${PANE}|${SESSION}" >> "$QUEUE"

# Resolve TTY for OSC 99 + BEL output
TTY=$(tmux display-message -p -t "$PANE" '#{pane_tty}' 2>/dev/null || echo /dev/tty)

# OSC 99: Kitty desktop notification protocol — propagates over SSH via tmux passthrough
# (requires: set -gq allow-passthrough on  ← already set in tmux.nix for image rendering)
MSG="${SESSION}: needs attention"
ID="$(date +%s)"
printf '\x1b]99;i=%s:d=0:p=title;Claude Code\x1b\\\x1b]99;i=%s:d=1:p=body;%s\x1b\\\a' \
    "$ID" "$ID" "$MSG" > "$TTY" 2>/dev/null || true

# Linux-only: also play peon sound + fire notify-send for local session UX
if [ "$(uname -s)" = Linux ]; then
    (
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Claude Code" "$MSG" -t 5000 -u normal
        fi
        "$(dirname "$0")"/peon-sound.sh input.required
    ) &
fi

# Try to become the popup manager using flock (atomic, immune to PID reuse)
exec 9>"$LOCK"
flock -n 9 || exit 0  # Another instance is already managing popups

# Process queue
while [ -s "$QUEUE" ]; do
    ITEM=$(head -1 "$QUEUE")
    sed -i '1d' "$QUEUE"

    ITEM_PANE="${ITEM%%|*}"
    ITEM_SESSION="${ITEM##*|}"

    # Find the most recently active tmux client
    CLIENT=$(tmux list-clients -F '#{client_activity} #{client_name}' \
        | sort -rn | head -1 | awk '{print $2}')
    [ -z "$CLIENT" ] && continue  # no clients attached, skip item

    # Open popup (blocks until popup closes)
    tmux display-popup -c "$CLIENT" \
        -w 80% -h 60% \
        -T " Claude: ${ITEM_SESSION} " \
        -E "bash $HOME/.config/home-manager/scripts/claude-popup.sh '${ITEM_PANE}' '${ITEM_SESSION}'" \
        2>/dev/null || true
done
# flock released automatically when fd 9 closes on exit
