#!/usr/bin/env bash
#============================================================================
# Kitty Tab Launch — attach to named tmux session with coordinator restore
# Used by kitty startup_session to reconnect tabs after reboot.
#
# First tab wins the lock, starts the tmux server, waits up to 15s for
# continuum to restore sessions. Other tabs wait for the coordinator signal.
#============================================================================
SESSION="${1:?Usage: kitty-tab-launch.sh SESSION_NAME}"
LOCK_DIR="/tmp/tmux-restore-$(id -u).lock"
DONE_FILE="/tmp/tmux-restore-$(id -u).done"

# Fast path: tmux server already running and session exists
tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"

# Fast path: restore already completed by a prior coordinator
[ -f "$DONE_FILE" ] && {
    tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"
    exec tmux new -s "$SESSION"
}

# --- Coordinator ---
# First tab to acquire the lock is responsible for starting the server
# and waiting for continuum to restore sessions.
if mkdir "$LOCK_DIR" 2>/dev/null; then
    # Boot the tmux server with a throwaway session so continuum fires
    tmux new-session -d -s "__restore_wait" 2>/dev/null

    # Wait up to 15s for continuum to restore our session
    for _ in $(seq 1 30); do
        sleep 0.5
        tmux has-session -t "$SESSION" 2>/dev/null && break
    done

    # Clean up the throwaway bootstrap session
    tmux kill-session -t "__restore_wait" 2>/dev/null

    # Signal followers that restore is done (or timed out)
    touch "$DONE_FILE"

    tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"
    exec tmux new -s "$SESSION"
fi

# --- Follower ---
# Wait for coordinator to finish (up to 20s)
for _ in $(seq 1 40); do
    sleep 0.5
    [ -f "$DONE_FILE" ] && break
done

tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"
exec tmux new -s "$SESSION"
