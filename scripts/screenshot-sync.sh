#!/usr/bin/env bash
# Watch ~/Pictures/Screenshots/ for new PNGs, scp to mac-studio, put remote path on clipboard.
# Runs as a systemd user service. Zero-touch: take screenshot → path ready to paste.

SCREENSHOTS_DIR="$HOME/Pictures/Screenshots"
MAC_HOST="100.68.68.16"
MAC_USER="ortho"
MAC_DIR="~/screenshots"
SSH_KEY="$HOME/.ssh/mac_studio_ed25519"
SSH_OPTS="-i $SSH_KEY -o IdentitiesOnly=yes -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no"

# Ensure remote dir exists (best-effort, silent)
ssh $SSH_OPTS "$MAC_USER@$MAC_HOST" "mkdir -p ~/screenshots" 2>/dev/null || true

inotifywait -m -e close_write --format '%f' "$SCREENSHOTS_DIR" 2>/dev/null |
while IFS= read -r filename; do
    [[ "$filename" != *.png ]] && continue
    local_path="$SCREENSHOTS_DIR/$filename"
    remote_display_path="~/screenshots/$filename"

    # Silent drop on failure (no internet, mac offline, etc.)
    if scp -q $SSH_OPTS "$local_path" "$MAC_USER@$MAC_HOST:~/screenshots/$filename" 2>/dev/null; then
        # Put image on mac clipboard so Claude Code image-paste works
        ssh $SSH_OPTS "$MAC_USER@$MAC_HOST" \
            "osascript -e 'set the clipboard to (read POSIX file \"/Users/$MAC_USER/screenshots/$filename\" as «class PNGf»)'" \
            2>/dev/null || true
        notify-send -t 4000 "Screenshot ready — paste in Claude Code on mac" "$remote_display_path"
    fi
done
