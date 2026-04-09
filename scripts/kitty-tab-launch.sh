#!/usr/bin/env bash
#============================================================================
# Kitty Tab Launch — attach to named tmux session after reboot
# Used by kitty startup_session to reconnect tabs.
#
# PRINCIPLE: sessions are sacred. Never create a bare session to replace
# an existing one. Only create if the session genuinely wasn't in the
# resurrect snapshot (i.e., restore completed and it's still missing).
#
# Coordinator (first tab): boots tmux server, triggers resurrect, waits.
# Followers: wait for coordinator to signal, then attach.
#
# NOTE: tmux-resurrect does NOT update the 'last' symlink during restore
# (only during save). Detection is based on session appearance only.
#============================================================================
SESSION="${1:?Usage: kitty-tab-launch.sh SESSION_NAME}"
LOCK_DIR="/tmp/tmux-restore-$(id -u).lock"
DONE_FILE="/tmp/tmux-restore-$(id -u).done"

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

    # Boot the tmux server with a throwaway session so continuum fires restore
    tmux new-session -d -s "__restore_wait" 2>/dev/null

    # Give continuum ~3s to auto-trigger restore on server start.
    # Continuum hooks into session-created to fire its restore on first boot.
    sleep 3

    # If continuum didn't restore our session, manually invoke the restore script.
    # This handles abrupt shutdowns and cases where the auto-restore hook misfires.
    if ! tmux has-session -t "$SESSION" 2>/dev/null; then
        RESTORE_SCRIPT=$(tmux show-option -gv @resurrect-restore-script-path 2>/dev/null)
        if [ -n "$RESTORE_SCRIPT" ] && [ -f "$RESTORE_SCRIPT" ]; then
            tmux run-shell "$RESTORE_SCRIPT"
        fi
    fi

    # Wait up to 30s for the target session to appear.
    # Resurrect restore is local tmux commands only — typically takes <3s.
    RESTORED=false
    for _ in $(seq 1 60); do
        sleep 0.5
        if tmux has-session -t "$SESSION" 2>/dev/null; then
            RESTORED=true
            break
        fi
    done

    # Clean up the throwaway bootstrap session
    tmux kill-session -t "__restore_wait" 2>/dev/null

    # Signal followers that restore is done (or timed out)
    touch "$DONE_FILE"

    if tmux has-session -t "$SESSION" 2>/dev/null; then
        exec tmux attach -t "$SESSION"
    fi

    if [ "$RESTORED" = true ]; then
        # Restore ran but this session wasn't in the snapshot (new since last save)
        exec tmux new -s "$SESSION"
    else
        # Restore failed — do NOT create a bare session
        echo "WARNING: tmux-resurrect restore did not complete."
        echo "Snapshot: $HOME/.tmux/resurrect/last"
        echo "Sessions available: $(tmux ls 2>/dev/null | awk -F: '{print $1}' | tr '\n' ' ')"
        echo ""
        echo "To restore manually: tmux attach -t __restore_wait, then Ctrl-A Ctrl-R"
        echo "Press Enter to retry attach, Ctrl-C to exit."
        read -r
        exec tmux attach -t "$SESSION" 2>/dev/null || exec tmux new -s "$SESSION"
    fi
fi

# --- Follower ---
# Wait for coordinator to finish (up to 40s: 3s continuum + 30s restore + buffer)
for _ in $(seq 1 80); do
    sleep 0.5
    [ -f "$DONE_FILE" ] && break
done

tmux has-session -t "$SESSION" 2>/dev/null && exec tmux attach -t "$SESSION"
exec tmux new -s "$SESSION"
