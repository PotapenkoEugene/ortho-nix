#!/usr/bin/env bash
# project-summary-popup.sh — tmux C-a n: fuzzy-pick a project, view its _summary.md
#
# Flow:
#   1. vault-sync pull in background (non-blocking)
#   2. Regenerate project summaries headlessly (nvim --headless)
#   3. tv fuzzy picker → select a project
#   4. exec nvim directly in this popup (popup IS the nvim session; :q closes it)
#      r = jump to raw note; R = regenerate summaries

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
    tv --no-preview
)

[ -z "$PROJECT" ] && exit 0

SUMMARY="$VAULT/projects/$PROJECT/_summary.md"
RAW_NOTE="$VAULT/projects/$PROJECT/$PROJECT.md"

[ -f "$SUMMARY" ] || { echo "No summary found for $PROJECT"; exit 1; }

# 4. Open summary directly in this popup.
# exec replaces the shell — popup closes when nvim exits (:q).
# -c flags run after file loads so buffer-local maps work correctly.
exec nvim "$SUMMARY" \
  -c "nnoremap <buffer> r :e ${RAW_NOTE}<CR>" \
  -c "nnoremap <buffer> R :GenerateSummaries<CR>"
