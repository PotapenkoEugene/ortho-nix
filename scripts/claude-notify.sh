#!/usr/bin/env bash
# Claude Code notification hook handler.
# Opens popup in user's active tmux client. Queues multiple notifications.
QUEUE="/tmp/claude-popup-queue"
LOCK="/tmp/claude-popup.pid"

# Get Claude's pane identity (inherited from Claude Code's environment)
PANE="${TMUX_PANE}"
SESSION=$(tmux display-message -p -t "$PANE" '#{session_name}' 2>/dev/null) || true
[ -z "$PANE" ] && exit 0

# Add to queue
echo "${PANE}|${SESSION}" >> "$QUEUE"

# Play sound + desktop notification (always, regardless of popup)
(
    /usr/bin/notify-send "Claude Code" "${SESSION}: needs attention" -t 5000 -u normal
    /home/ortho/.config/home-manager/scripts/peon-sound.sh input.required
) &

# Try to become the popup manager (PID-based lock)
if [ -f "$LOCK" ]; then
    OLD_PID=$(cat "$LOCK" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0  # Another instance is managing popups
    fi
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# Process queue
while [ -s "$QUEUE" ]; do
    ITEM=$(head -1 "$QUEUE")
    sed -i '1d' "$QUEUE"

    ITEM_PANE="${ITEM%%|*}"
    ITEM_SESSION="${ITEM##*|}"

    # Find the most recently active tmux client
    CLIENT=$(tmux list-clients -F '#{client_activity} #{client_name}' \
        | sort -rn | head -1 | awk '{print $2}')
    [ -z "$CLIENT" ] && break

    # Skip popup if the active client is already viewing Claude's session
    CLIENT_SESSION=$(tmux display-message -p -c "$CLIENT" '#{session_name}' 2>/dev/null)
    [ "$CLIENT_SESSION" = "$ITEM_SESSION" ] && continue

    # Open popup (blocks until popup closes)
    tmux display-popup -c "$CLIENT" \
        -w 80% -h 60% \
        -T " Claude: ${ITEM_SESSION} " \
        -E "bash /home/ortho/.config/home-manager/scripts/claude-popup.sh '${ITEM_PANE}' '${ITEM_SESSION}'" \
        2>/dev/null || true
done
