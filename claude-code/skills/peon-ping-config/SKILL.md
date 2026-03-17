---
name: peon-ping-config
description: Update peon-ping configuration — volume, pack rotation, categories, active pack, and other settings. Use when user wants to change peon-ping settings like volume, enable round-robin, add packs to rotation, toggle sound categories, or adjust any config.
user_invocable: true
---

# peon-ping-config

Manage peon-ping sound pack configuration.

## Config file

`/home/ortho/.config/home-manager/sounds/config.json`

Fields:
- **active_pack** (string): Directory name of the active sound pack (e.g. `"glados"`, `"peon"`, `"sc_kerrigan"`). Set to `"random"` to pick a random pack each time (original behavior).
- **muted** (boolean): If `true`, all sounds are silenced.

## Steps

1. **Read** the config file to show current state:
   ```
   Active pack: glados (GLaDOS (Portal))
   Muted: false
   ```

2. **List available packs** by reading each `openpeon.json` manifest:
   ```bash
   for f in /home/ortho/.config/home-manager/sounds/*/openpeon.json; do /usr/bin/jq -r '"\(.name)\t\(.display_name)"' "$f"; done
   ```
   Display as a table with directory name and display name.

3. **If the user wants to change the active pack**, use the Edit tool to update `active_pack` in the config file. Use the directory name (the `name` field from openpeon.json), not the display name.

4. **If the user wants "random"**, set `active_pack` to `"random"`.

5. Confirm the change and report the new state.

## Important

- The config file is tracked in the repo at `sounds/config.json` — use the Edit tool, not Bash.
- Pack directory names match the `name` field in each pack's `openpeon.json`.
- If a pack doesn't have sounds for a category, `peon-sound.sh` falls back to random selection for that category only.
