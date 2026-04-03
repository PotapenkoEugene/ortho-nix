#!/usr/bin/env bash
#============================================================================
# Kitty Tab Launch — attach to named tmux session after reboot
# Used by kitty startup_session to reconnect tabs.
#
# PRINCIPLE: sessions are sacred. Never create a bare session to replace
# an existing one. Only create if the session genuinely wasn't in the
# resurrect snapshot (i.e., restore completed and it's still missing).
#
# Coordinator (first tab): boots tmux server, waits for resurrect to finish.
# Followers: wait for coordinator to signal, then attach.
#============================================================================
SESSION="${1:?Usage: kitty-tab-launch.sh SESSION_NAME}"
LOCK_DIR="/tmp/tmux-restore-$(id -u).lock"
DONE_FILE="/tmp/tmux-restore-$(id -u).done"
RESURRECT_DIR="$HOME/.tmux/resurrect"

# Fast path: tmux server already running and session exists
tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"

# Fast path: restore already completed by a prior coordinator
if [ -f "$DONE_FILE" ]; then
    tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"
    # Session not in snapshot — create new (it was added after last save)
    exec tmux new -s "$SESSION"
fi

# --- Coordinator ---
# First tab to acquire the lock is responsible for starting the tmux server
# and waiting for resurrect to finish restoring all sessions.
if mkdir "$LOCK_DIR" 2>/dev/null; then

    # Note the current 'last' snapshot before restore so we can detect when
    # resurrect updates it (it rewrites the symlink on restore completion).
    BEFORE_RESTORE=$(readlink "$RESURRECT_DIR/last" 2>/dev/null)

    # Boot the tmux server with a throwaway session so continuum fires restore
    tmux new-session -d -s "__restore_wait" 2>/dev/null

    # Wait up to 120s for resurrect restore to complete.
    # Detect completion two ways:
    #   1. The 'last' symlink changes (resurrect rewrites it on restore)
    #   2. Our target session appears (it was restored)
    RESTORED=false
    for _ in $(seq 1 240); do
        sleep 0.5

        # Check if our session appeared
        if tmux has-session -t "$SESSION" 2>/dev/null; then
            RESTORED=true
            break
        fi

        # Check if the resurrect 'last' symlink changed (restore completed)
        CURRENT=$(readlink "$RESURRECT_DIR/last" 2>/dev/null)
        if [ -n "$CURRENT" ] && [ "$CURRENT" != "$BEFORE_RESTORE" ]; then
            RESTORED=true
            break
        fi
    done

    # Clean up the throwaway bootstrap session
    tmux kill-session -t "__restore_wait" 2>/dev/null

    # Signal followers that restore is done (or timed out after 120s)
    touch "$DONE_FILE"

    if tmux has-session -t "$SESSION" 2>/dev/null; then
        exec tmux attach -t "$SESSION"
    fi

    if [ "$RESTORED" = true ]; then
        # Restore ran but this session wasn't in the snapshot (new since last save)
        exec tmux new -s "$SESSION"
    else
        # Restore timed out — do NOT create a bare session, just attach to whatever exists
        # or open a rescue shell so the user can investigate
        echo "WARNING: tmux-resurrect restore did not complete within 120s."
        echo "Sessions may still be restoring. Try: tmux ls"
        echo "To attach manually: tmux attach -t $SESSION"
        echo "Press Enter to retry attach, Ctrl-C to exit."
        read -r
        exec tmux attach -t "$SESSION" 2>/dev/null || exec tmux new -s "$SESSION"
    fi
fi

# --- Follower ---
# Wait for coordinator to finish (up to 125s)
for _ in $(seq 1 250); do
    sleep 0.5
    [ -f "$DONE_FILE" ] && break
done

tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"
exec tmux new -s "$SESSION"
