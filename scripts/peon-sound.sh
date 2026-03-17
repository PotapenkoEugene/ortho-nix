#!/usr/bin/env bash
# Play a random sound from a configured pack for the given CESP category.
# Usage: peon-sound.sh <cesp-category>
# e.g.: peon-sound.sh input.required
set -euo pipefail

CATEGORY="${1:-}"
[ -z "$CATEGORY" ] && exit 1

SOUNDS_DIR="/home/ortho/.config/home-manager/sounds"
CONFIG="$SOUNDS_DIR/config.json"

# Read config (fall back to random + unmuted if missing)
if [ -f "$CONFIG" ]; then
    MUTED=$(/usr/bin/jq -r '.muted // false' "$CONFIG")
    ACTIVE_PACK=$(/usr/bin/jq -r '.active_pack // "random"' "$CONFIG")
else
    MUTED=false
    ACTIVE_PACK=random
fi

# Exit silently if muted
[ "$MUTED" = "true" ] && exit 0

# Build list of candidate packs
PACKS=()
if [ "$ACTIVE_PACK" = "random" ]; then
    # Original behavior: all packs with sounds for this category
    for manifest in "$SOUNDS_DIR"/*/openpeon.json; do
        count=$(/usr/bin/jq -r ".categories.\"$CATEGORY\".sounds | length" "$manifest" 2>/dev/null)
        [ "$count" -gt 0 ] && PACKS+=("$(dirname "$manifest")")
    done
else
    # Single pack mode
    manifest="$SOUNDS_DIR/$ACTIVE_PACK/openpeon.json"
    if [ -f "$manifest" ]; then
        count=$(/usr/bin/jq -r ".categories.\"$CATEGORY\".sounds | length" "$manifest" 2>/dev/null)
        if [ "$count" -gt 0 ]; then
            PACKS+=("$SOUNDS_DIR/$ACTIVE_PACK")
        else
            # Fallback to random if active pack lacks this category
            for manifest in "$SOUNDS_DIR"/*/openpeon.json; do
                count=$(/usr/bin/jq -r ".categories.\"$CATEGORY\".sounds | length" "$manifest" 2>/dev/null)
                [ "$count" -gt 0 ] && PACKS+=("$(dirname "$manifest")")
            done
        fi
    fi
fi

[ ${#PACKS[@]} -eq 0 ] && exit 1

# Pick random pack
PACK="${PACKS[$((RANDOM % ${#PACKS[@]}))]}"

# Pick random sound file from that pack's category
SOUND=$(/usr/bin/jq -r ".categories.\"$CATEGORY\".sounds[].file" "$PACK/openpeon.json" | /usr/bin/shuf -n1)

# Play it
/home/ortho/.nix-profile/bin/pw-play "$PACK/$SOUND" 2>>/tmp/peon-debug.log
