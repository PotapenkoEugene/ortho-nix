#!/usr/bin/env bash
# nvim-editor-popup.sh — open a file in nvim as a tmux popup
# Used as $EDITOR for Claude Code chat:externalEditor (Ctrl+A+E)
# Falls back to plain nvim when not inside tmux

FILE="${1:?Usage: nvim-editor-popup.sh <file>}"

# Ensure secrets are in env before forwarding to the popup.
# tmux display-popup spawns from the tmux server's env, not ours,
# so we must pass needed vars explicitly via -e.
if [ -z "${OPENAI_API_KEY:-}" ] && [ -f ~/.secrets/env ]; then
  # shellcheck disable=SC1090
  source ~/.secrets/env
fi

if [ -n "${TMUX:-}" ]; then
  tmux display-popup -w 90% -h 90% \
    -e "OPENAI_API_KEY=${OPENAI_API_KEY:-}" \
    -e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" \
    -e "CLAUDE_CODE_OAUTH_TOKEN=${CLAUDE_CODE_OAUTH_TOKEN:-}" \
    -E "nvim $(printf '%q' "$FILE")"
else
  nvim "$FILE"
fi
