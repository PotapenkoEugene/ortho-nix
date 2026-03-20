#!/usr/bin/env bash
# Popup UI for Claude Code permission prompts.
# Type 1-5 to stage a choice, Enter to send. Press q to close without sending.
PANE="$1"    # tmux pane ID (e.g., %15)
LABEL="$2"   # session name for display

BASELINE=$(tmux capture-pane -p -t "$PANE" 2>/dev/null | md5sum | cut -d' ' -f1)
PENDING=""
LAST_HASH=""
LAST_PENDING=""

render() {
    local content hash
    content=$(tmux capture-pane -ep -t "$PANE" -S -25 2>/dev/null) || exit 0
    hash=$(printf '%s' "$content" | md5sum | cut -d' ' -f1)
    # Only redraw if pane content or pending key changed
    [ "$hash" = "$LAST_HASH" ] && [ "$PENDING" = "$LAST_PENDING" ] && return
    LAST_HASH="$hash"
    LAST_PENDING="$PENDING"
    clear
    printf '\e[1;34m  Claude Code: %s \e[0m\n\n' "$LABEL"
    printf '%s\e[0m\n' "$content"
    printf '\n\e[2m%s\e[0m\n' "$(printf '─%.0s' $(seq 1 "${COLUMNS:-80}"))"
    if [ -n "$PENDING" ]; then
        printf '  \e[1;32m> %s\e[0m     \e[2m[Enter] send  [q] close\e[0m\n' "$PENDING"
    else
        printf '  \e[2mType 1-5 then Enter to respond     [q] close\e[0m\n'
    fi
}

render
while true; do
    if read -rsn1 -t 0.5 key; then
        case "$key" in
            q|Q)
                exit 0  # close without sending
                ;;
            $'\x1b')  # absorb escape sequences (arrow keys etc.)
                read -rsn5 -t 0.02 _extra
                ;;
            "")  # Enter
                if [[ "$PENDING" =~ ^[1-5]$ ]]; then
                    tmux send-keys -t "$PANE" -l "$PENDING"
                    sleep 0.1
                    exit 0
                fi
                # invalid input — do nothing
                ;;
            [1-5])
                PENDING="$key"
                render
                ;;
            *)
                # any other key — clear pending and show invalid state
                PENDING=""
                render
                ;;
        esac
    else
        # Timeout — close if Claude moved on, otherwise maybe refresh
        NOW=$(tmux capture-pane -p -t "$PANE" 2>/dev/null | md5sum | cut -d' ' -f1)
        [ "$NOW" != "$BASELINE" ] && exit 0
        render
    fi
done
