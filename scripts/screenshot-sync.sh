#!/usr/bin/env bash
# Watch ~/Pictures/Screenshots/ for new PNGs, scp to mac-studio, put remote path on clipboard.
# Runs as a systemd user service. Zero-touch: take screenshot → path ready to paste.

SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
MAC_HOST="100.68.68.16"
MAC_USER="ortho"
MAC_DIR="~/screenshots"
SSH_KEY="$HOME/.ssh/mac_studio_ed25519"
SSH_OPTS="-i $SSH_KEY -o IdentitiesOnly=yes -o ConnectTimeout=10 -o BatchMode=yes"

# Ensure remote dir exists
ssh $SSH_OPTS "$MAC_USER@$MAC_HOST" "mkdir -p ~/screenshots" 2>/dev/null

inotifywait -m -e close_write --format '%f' "$SCREENSHOTS_DIR" 2>/dev/null |
while IFS= read -r filename; do
    [[ "$filename" != *.png ]] && continue
    local_path="$SCREENSHOTS_DIR/$filename"
    remote_display_path="~/screenshots/$filename"

    scp -q $SSH_OPTS "$local_path" "$MAC_USER@$MAC_HOST:~/screenshots/$filename"

    if [[ $? -eq 0 ]]; then
        printf '%s' "$remote_display_path" | wl-copy
        notify-send -t 4000 "Screenshot ready" "$remote_display_path"
    else
        notify-send -u critical -t 6000 "Screenshot sync failed" "$filename"
    fi
done
