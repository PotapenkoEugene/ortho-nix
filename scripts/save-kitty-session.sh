#!/usr/bin/env bash
#============================================================================
# Save Kitty Session — dump attached tmux sessions to kitty session file
# Called by tmux hooks (session-created, session-closed, client-session-changed)
# Writes ~/.config/kitty/session.conf for startup_session restore.
#============================================================================
SESSION_FILE="$HOME/.config/kitty/session.conf"

# Don't overwrite session.conf during the first 3 minutes after boot.
# Resurrect restore may still be in progress — overwriting now would lock in
# a degraded state (only tabs that opened before restore completed).
UPTIME_SECS=$(awk '{print int($1)}' /proc/uptime)
if [ "$UPTIME_SECS" -lt 180 ]; then
    exit 0
fi

# Get attached tmux sessions ordered by client creation time (preserves tab order)
SESSIONS=$(tmux list-clients -F '#{client_created} #{session_name}' 2>/dev/null \
    | sort -n | awk '{print $2}' | awk '!seen[$0]++')

# Don't overwrite if no clients attached (e.g. running from cron with no kitty)
if [ -z "$SESSIONS" ]; then
    exit 0
fi

mkdir -p "$(dirname "$SESSION_FILE")"

# Generate kitty session file
{
    FIRST=true
    while IFS= read -r name; do
        if [ "$FIRST" = true ]; then
            echo "new_tab $name"
            echo "launch kitty-tab-launch.sh $name"
            FIRST=false
        else
            echo ""
            echo "new_tab $name"
            echo "launch kitty-tab-launch.sh $name"
        fi
    done <<< "$SESSIONS"
} > "$SESSION_FILE"
