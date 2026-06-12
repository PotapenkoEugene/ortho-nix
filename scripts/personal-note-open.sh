#!/usr/bin/env bash
# personal-note-open.sh — open today's personal daily note in nvim.
#
# Called by:
#   Linux: GNOME Super+n keybinding  (via kitty)
#   Mac:   skhd cmd+alt-n            (via kitty)
#
# Flow:
#   1. vault-sync pull (get overnight Mac-generated note if available)
#   2. If note doesn't exist yet, generate it headlessly using the lua script
#   3. exec nvim <today's note>
#
# The caller (GNOME/skhd keybinding) launches kitty with this script as the command,
# so nvim runs inside a fresh kitty window.

VAULT="$HOME/Orthidian"
TODAY="$VAULT/daily/$(date +%Y-%m-%d).md"
SCRIPT="$HOME/.config/home-manager/scripts/obsidian_daily_notes.lua"

# 1. Pull latest vault (non-blocking failure: offline is fine, just open whatever we have)
vault-sync 2>/dev/null || true

# 2. Generate today's note if missing (runs lua headlessly; calendar fetch happens inside)
if [ ! -f "$TODAY" ]; then
  mkdir -p "$VAULT/daily"
  (
    cd "$VAULT" || exit 1
    nvim --headless --noplugin \
      -c "luafile $SCRIPT" \
      -c 'qa!' 2>/dev/null
  ) || true
fi

# 3. Open in nvim (exec replaces this shell so kitty's exit closes cleanly)
exec nvim "$TODAY"
