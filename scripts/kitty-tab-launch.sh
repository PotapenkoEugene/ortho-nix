#!/usr/bin/env bash
#============================================================================
# Kitty Tab Launch — attach to named tmux session with retry
# Used by kitty startup_session to reconnect tabs after reboot.
# Waits for continuum to restore sessions before falling back to new.
#============================================================================
SESSION="${1:?Usage: kitty-tab-launch.sh SESSION_NAME}"

# Try to attach immediately
tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"

# Wait for continuum restore (up to 5 seconds)
for _ in $(seq 1 10); do
    sleep 0.5
    tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"
done

# Fallback: create new session
exec tmux new -s "$SESSION"
