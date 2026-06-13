#!/usr/bin/env bash
# project-summary-popup.sh — tmux C-a n: fuzzy-pick a project, view its _summary.md
#
# Flow:
#   1. vault-sync pull (get latest summaries)
#   2. Regenerate project summaries headlessly (nvim --headless)
#   3. tv fuzzy picker → select a project
#   4. Open projects/<SELECTED>/_summary.md in the persistent -L notes nvim session
#      r = jump to raw note; R = regenerate summaries

SESSION="notes"
SOCK="notes"
VAULT="$HOME/Orthidian"
GEN_SCRIPT="$HOME/.config/home-manager/scripts/generate-summaries.lua"

unset TMUX

# 1. Pull latest vault in background (don't block / clutter the picker)
vault-sync >/dev/null 2>&1 &

# 2. Regenerate project summaries headlessly
# CWD must be VAULT so nvim's getcwd() resolves as the vault root.
(
  cd "$VAULT" || exit 1
  nvim --headless --noplugin \
    -c "luafile $GEN_SCRIPT" \
    -c 'qa!' 2>/dev/null
) || true

# 3. Fuzzy-pick a project via tv
# List all subdir names under projects/ that have a _summary.md
PROJECT=$(
  find "$VAULT/projects" -maxdepth 2 -name "_summary.md" -print0 2>/dev/null |
    xargs -0 -I{} dirname {} |
    while read -r d; do basename "$d"; done |
    sort -u |
    tv --no-preview 2>/dev/null
)

[ -z "$PROJECT" ] && exit 0

SUMMARY="$VAULT/projects/$PROJECT/_summary.md"
RAW_NOTE="$VAULT/projects/$PROJECT/$PROJECT.md"

[ -f "$SUMMARY" ] || { echo "No summary found for $PROJECT"; exit 1; }

# 4. Open summary in persistent -L notes nvim session
if ! tmux -L "$SOCK" has-session -t "$SESSION" 2>/dev/null; then
  tmux -L "$SOCK" new-session -d -s "$SESSION" -c "$VAULT" "nvim '$SUMMARY'"
else
  # Session exists: switch to the summary file
  tmux -L "$SOCK" send-keys -t "$SESSION" Escape ""
  tmux -L "$SOCK" send-keys -t "$SESSION" ":e $SUMMARY" Enter
fi

# Map buffer-local keys (set via send-keys into the session after file opens)
# r = open raw note in same window; R = regenerate all summaries
sleep 0.3
tmux -L "$SOCK" send-keys -t "$SESSION" \
  ":nnoremap <buffer> r :e ${RAW_NOTE}<CR>" Enter
tmux -L "$SOCK" send-keys -t "$SESSION" \
  ":nnoremap <buffer> R :GenerateSummaries<CR>" Enter

tmux -L "$SOCK" attach-session -t "$SESSION"
