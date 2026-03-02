#!/usr/bin/env bash
# Popup UI for Claude Code permission prompts.
# Captures target pane, forwards keypresses, auto-closes when Claude processes input.
PANE="$1"    # tmux pane ID (e.g., %15)
LABEL="$2"   # session name for display

BASELINE=$(tmux capture-pane -p -t "$PANE" 2>/dev/null | md5sum | cut -d' ' -f1)
LAST_CONTENT=""

refresh() {
    local content
    content=$(tmux capture-pane -ep -t "$PANE" -S -25 2>/dev/null) || exit 0
    if [ "$content" != "$LAST_CONTENT" ]; then
        clear
        printf '\e[1;34m  Claude Code: %s \e[0m\n\n' "$LABEL"
        printf '%s\e[0m\n' "$content"
        printf '\n\e[2m  [Esc] close  |  keys forwarded to Claude\e[0m\n'
        LAST_CONTENT="$content"
    fi
}

refresh
while true; do
    if read -rsn1 -t 0.5 key; then
        case "$key" in
            $'\x1b')  # Escape or escape sequence
                read -rsn5 -t 0.02 extra
                [ -z "$extra" ] && exit 0  # bare Escape = close
                tmux send-keys -t "$PANE" Escape  # forward
                ;;
            "")  # Enter
                tmux send-keys -t "$PANE" Enter
                ;;
            *)
                tmux send-keys -t "$PANE" -l "$key"
                ;;
        esac
        sleep 0.2
        NOW=$(tmux capture-pane -p -t "$PANE" 2>/dev/null | md5sum | cut -d' ' -f1)
        [ "$NOW" != "$BASELINE" ] && exit 0  # Claude accepted input -> close
        refresh
    else
        # Periodic check -- close if content changed externally
        NOW=$(tmux capture-pane -p -t "$PANE" 2>/dev/null | md5sum | cut -d' ' -f1)
        [ "$NOW" != "$BASELINE" ] && exit 0
        refresh
    fi
done
