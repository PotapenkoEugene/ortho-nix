#!/usr/bin/env bash
#============================================================================
# Transcript Cleanup — two-layer: timestamp interleave + LLM polish
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
# Layer 1: Parse timestamps, label speakers, sort chronologically.
# Layer 2: LLM cleans grammar and merges fragments.
#============================================================================
set -euo pipefail

INPUT="${1:?Usage: clean-transcript.sh <input-file> [output-file]}"
OUTPUT="${2:-${INPUT%.txt}-clean.txt}"

MODEL="$HOME/llm-models/qwen2.5-3b-instruct-q4_k_m.gguf"
THREADS=12

notify() {
    notify-send "Transcript Cleanup" "$1" -t 5000 2>/dev/null || true
}

if [ ! -f "$INPUT" ]; then
    echo "Error: input file not found: $INPUT" >&2
    exit 1
fi

if [ ! -f "$MODEL" ]; then
    echo "Error: LLM model not found: $MODEL" >&2
    echo "Run 'home-manager switch' to download it." >&2
    exit 1
fi

RAW_LINES=$(wc -l < "$INPUT")

#--- Layer 1: Parse, label, sort by timestamp ---
# Extracts timestamped lines from [System Audio] and [Mic] sections,
# labels them Other:/Me:, sorts by start time, strips timestamps.

SORTED=$(awk '
/^\[System Audio\]/ { speaker = "Other"; next }
/^\[Mic\]/ { speaker = "Me"; next }
/^\[([0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+) --> / {
    # Extract start timestamp for sorting
    match($0, /^\[([0-9]{2}):([0-9]{2}):([0-9]{2})\.([0-9]+)/, t)
    # Convert to milliseconds for numeric sort
    ms = (t[1]*3600 + t[2]*60 + t[3]) * 1000 + int(t[4])
    # Extract text after the timestamp bracket
    text = $0
    sub(/^\[[0-9:. >-]+\] */, "", text)
    # Skip empty/noise lines
    if (text == "" || text == "[BLANK_AUDIO]") next
    if (text ~ /^\(speaking in foreign language\)$/) next
    # Output: sortable_ms | speaker | text
    printf "%012d|%s|%s\n", ms, speaker, text
    next
}
' "$INPUT" | sort -t'|' -k1,1n | while IFS='|' read -r _ speaker text; do
    echo "${speaker}: ${text}"
done)

SORTED_LINES=$(echo "$SORTED" | grep -c . || true)

if [ "$SORTED_LINES" -lt 1 ]; then
    echo "Warning: no timestamped content found. Skipping LLM." >&2
    notify "Cleanup skipped — no content"
    exit 0
fi

echo "Layer 1: $RAW_LINES raw -> $SORTED_LINES sorted lines"

#--- Layer 2: LLM polish via llama-completion ---
# Speaker labels are already correct. LLM just cleans grammar,
# merges consecutive same-speaker lines, removes fillers.

TMPFILE=$(mktemp /tmp/transcript-prompt-XXXXXX.txt)
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" << CHATML
<|im_start|>system
You clean up a pre-labeled conversation transcript. Output in English only.
The speaker labels (Other:/Me:) are already correct — do not change them.

Rules:
1. Merge consecutive lines from the same speaker into one paragraph.
2. Fix grammar and remove filler words (um, uh, like, so, okay).
3. Keep all technical terms, names, and numbers exact.
4. Keep every labeled line — do not drop or skip any content.
5. Output the cleaned dialog only, no commentary, no translation.<|im_end|>
<|im_start|>user
${SORTED}<|im_end|>
<|im_start|>assistant
CHATML

echo "Layer 2: Running LLM cleanup..."

RESULT=$(llama-completion \
    -m "$MODEL" \
    --threads "$THREADS" \
    --ctx-size 4096 \
    -ngl 99 \
    --temp 0.1 \
    --no-display-prompt \
    -no-cnv \
    -f "$TMPFILE" \
    -n 1024 2>/dev/null)

# Strip special tokens and leading non-letter junk from model output
RESULT=$(echo "$RESULT" | \
    sed 's/\[end of text\]//g; s/<|im_end|>//g' | \
    sed '1s/^[^A-Za-z]*//' | \
    sed -e 's/[[:space:]]*$//')

CLEAN_LINES=$(echo "$RESULT" | wc -l)

echo "$RESULT" > "$OUTPUT"

echo "Done: $RAW_LINES raw -> $SORTED_LINES sorted -> $CLEAN_LINES clean"
echo "Output: $OUTPUT"

notify "Transcript cleaned\n${RAW_LINES} -> ${CLEAN_LINES} lines\n$(basename "$OUTPUT")"
