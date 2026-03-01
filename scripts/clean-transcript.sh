#!/usr/bin/env bash
#============================================================================
# Transcript Cleanup — timestamp interleave + merge consecutive speakers
# Usage: clean-transcript.sh <input-file> [output-file]
#
# Input format (from whisper-stream-toggle.sh):
#   [System Audio]
#   [00:00:00.000 --> 00:00:05.000]  Hello, how are you?
#   ...
#   [Mic]
#   [00:00:00.000 --> 00:00:03.000]  I'm good thanks.
#   ...
#
# Parses timestamps, labels speakers, sorts chronologically,
# merges consecutive same-speaker lines into paragraphs.
# No LLM needed — deterministic awk processing only.
#============================================================================
set -euo pipefail

INPUT="${1:?Usage: clean-transcript.sh <input-file> [output-file]}"
OUTPUT="${2:-${INPUT%.txt}-clean.txt}"

notify() {
    notify-send "Transcript Cleanup" "$1" -t 5000 2>/dev/null || true
}

if [ ! -f "$INPUT" ]; then
    echo "Error: input file not found: $INPUT" >&2
    exit 1
fi

RAW_LINES=$(wc -l < "$INPUT")

# Parse timestamps, label speakers, sort, merge consecutive same-speaker lines
RESULT=$(awk '
/^\[System Audio\]/ { speaker = "Other"; next }
/^\[Mic\]/ { speaker = "Me"; next }
/^\[([0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+) --> / {
    match($0, /^\[([0-9]{2}):([0-9]{2}):([0-9]{2})\.([0-9]+)/, t)
    ms = (t[1]*3600 + t[2]*60 + t[3]) * 1000 + int(t[4])
    text = $0
    sub(/^\[[0-9:. >-]+\] */, "", text)
    if (text == "" || text == "[BLANK_AUDIO]") next
    if (text == "[Inaudible]") next
    if (text ~ /^\(speaking in foreign language\)$/) next
    printf "%012d|%s|%s\n", ms, speaker, text
    next
}
' "$INPUT" | sort -t'|' -k1,1n | awk -F'|' '
{
    speaker = $2
    text = $3
    if (speaker == prev_speaker) {
        # Same speaker — append to current paragraph
        paragraph = paragraph " " text
    } else {
        # New speaker — flush previous paragraph
        if (paragraph != "") print prev_speaker ": " paragraph
        paragraph = text
        prev_speaker = speaker
    }
}
END {
    if (paragraph != "") print prev_speaker ": " paragraph
}
')

CLEAN_LINES=$(echo "$RESULT" | grep -c . || true)

if [ "$CLEAN_LINES" -lt 1 ]; then
    echo "Warning: no content found." >&2
    notify "Cleanup skipped — no content"
    exit 0
fi

echo "$RESULT" > "$OUTPUT"

echo "Done: $RAW_LINES raw -> $CLEAN_LINES clean"
echo "Output: $OUTPUT"

notify "Transcript cleaned\n${RAW_LINES} -> ${CLEAN_LINES} lines\n$(basename "$OUTPUT")"
