#!/usr/bin/env bash
# Play a random sound from a random pack for the given CESP category.
# Usage: peon-sound.sh <cesp-category>
# e.g.: peon-sound.sh input.required
set -euo pipefail

CATEGORY="${1:-}"
[ -z "$CATEGORY" ] && exit 1

SOUNDS_DIR="/home/ortho/.config/home-manager/sounds"

# Find all packs that have sounds for this category
PACKS=()
for manifest in "$SOUNDS_DIR"/*/openpeon.json; do
    count=$(/usr/bin/jq -r ".categories.\"$CATEGORY\".sounds | length" "$manifest" 2>/dev/null)
    [ "$count" -gt 0 ] && PACKS+=("$(dirname "$manifest")")
done

[ ${#PACKS[@]} -eq 0 ] && exit 1

# Pick random pack
PACK="${PACKS[$((RANDOM % ${#PACKS[@]}))]}"

# Pick random sound file from that pack's category
SOUND=$(/usr/bin/jq -r ".categories.\"$CATEGORY\".sounds[].file" "$PACK/openpeon.json" | /usr/bin/shuf -n1)

# Play it
/home/ortho/.nix-profile/bin/pw-play "$PACK/$SOUND" 2>>/tmp/peon-debug.log
