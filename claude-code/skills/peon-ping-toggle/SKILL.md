---
name: peon-ping-toggle
description: Toggle peon-ping sound notifications on/off. Use when user wants to mute, unmute, pause, or resume peon sounds during a Claude Code session. Also handles config changes like volume, pack rotation, categories — any peon-ping setting.
user_invocable: true
---

# peon-ping-toggle

Toggle peon-ping sounds on or off.

## Config file

`/home/ortho/.config/home-manager/sounds/config.json`

## Steps

1. **Read** the config file to check current `muted` state.
2. **Toggle** the `muted` field using the Edit tool:
   - If `"muted": false` → change to `"muted": true`
   - If `"muted": true` → change to `"muted": false`
3. **Report** the new state:
   - `Peon sounds: muted` — sounds are now silenced
   - `Peon sounds: unmuted` — sounds are now active

## For other config changes

If the user wants to change the active pack, volume, or other settings, use the `peon-ping-config` skill instead.
