#!/bin/bash
SESSION="vpn-migal"
SOCK="vpn"
unset TMUX

if ! tmux -L "$SOCK" has-session -t "$SESSION" 2>/dev/null; then
    tmux -L "$SOCK" new-session -d -s "$SESSION" \
        "sudo /home/ortho/.nix-profile/bin/openfortivpn"
fi

# Escape to detach (no prefix needed) for quick close
tmux -L "$SOCK" bind-key -n Escape detach-client

tmux -L "$SOCK" attach-session -t "$SESSION"
