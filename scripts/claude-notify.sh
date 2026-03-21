#!/usr/bin/env bash
# Claude Code notification hook handler.
# Opens popup in user's active tmux client. Queues multiple notifications.
QUEUE="/tmp/claude-popup-queue"
LOCK="/tmp/claude-popup.lock"

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
        -E "bash /home/ortho/.config/home-manager/scripts/claude-popup.sh '${ITEM_PANE}' '${ITEM_SESSION}'" \
        2>/dev/null || true
done
# flock released automatically when fd 9 closes on exit
