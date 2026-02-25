#!/usr/bin/env bash
#============================================================================
# Transcript Cleanup — two-layer: awk deduplication + LLM polish
# Usage: clean-transcript.sh <input-file> [output-file]
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

#--- Layer 1: Deterministic deduplication with awk ---
# Whisper-stream produces blocks separated by blank lines.
# Each block starting with [00:00:00.000 ...] is a window refinement.
# Keep only the LAST block before each new window reset (most refined).
# Strip timestamps, [BLANK_AUDIO], (speaking in foreign language).

DEDUPED=$(awk '
BEGIN { block = ""; last_block = "" }

# Blank line = end of block
/^[[:space:]]*$/ {
    if (block != "") {
        # Check if this block starts a new window (timestamp resets to 00:00:00)
        if (block ~ /^\[00:00:00\.000/) {
            # Same window refinement — replace previous
            last_block = block
        } else {
            # Different timestamps — this is continuation, flush previous and keep
            if (last_block != "") {
                printf "%s\n\n", last_block
            }
            last_block = block
        }
        block = ""
    }
    next
}

# Accumulate lines into current block
{
    if (block == "") block = $0
    else block = block "\n" $0
}

END {
    # Flush remaining
    if (block != "") {
        if (last_block != "" && block ~ /^\[00:00:00\.000/) {
            # Last block is another refinement, use it instead
            printf "%s\n", block
        } else {
            if (last_block != "") printf "%s\n\n", last_block
            if (block != "") printf "%s\n", block
        }
    } else if (last_block != "") {
        printf "%s\n", last_block
    }
}
' "$INPUT" | \
    sed 's/\[00:00:[0-9.]*\s*-->\s*[0-9:.]*\]\s*//g' | \
    grep -v '^\[BLANK_AUDIO\]$' | \
    grep -v '^(speaking in foreign language)$' | \
    sed '/^[[:space:]]*$/{ N; /^\n[[:space:]]*$/d; }' | \
    sed 's/^[[:space:]]*//')

DEDUPED_LINES=$(echo "$DEDUPED" | wc -l)

# If dedup produced nothing useful, bail out
if [ "$DEDUPED_LINES" -lt 2 ]; then
    echo "Warning: deduplication produced too little content ($DEDUPED_LINES lines). Skipping LLM." >&2
    notify "Cleanup skipped — too little content after dedup"
    exit 0
fi

echo "Layer 1: $RAW_LINES -> $DEDUPED_LINES lines after deduplication"

#--- Layer 2: LLM cleanup via llama-completion ---
# Uses llama-completion (not llama-cli) for non-interactive one-shot mode.
# ChatML template constructed manually, -no-cnv disables conversation mode.
# ctx-size 2048 is enough for deduped transcripts (~2.4 GB RAM total).

TMPFILE=$(mktemp /tmp/transcript-prompt-XXXXXX.txt)
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" << CHATML
<|im_start|>system
You are a transcript cleaner. Given raw speech-to-text output, produce clean readable text. Rules: fix grammar, remove filler words (um, uh, so, okay, like), merge fragments, remove repetition. Keep all technical terms, names, numbers exact. Output the cleaned text only, no commentary.<|im_end|>
<|im_start|>user
${DEDUPED}<|im_end|>
<|im_start|>assistant
CHATML

echo "Layer 2: Running LLM cleanup..."

RESULT=$(llama-completion \
    -m "$MODEL" \
    --threads "$THREADS" \
    --ctx-size 2048 \
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

echo "Done: $RAW_LINES raw -> $DEDUPED_LINES deduped -> $CLEAN_LINES clean"
echo "Output: $OUTPUT"

notify "Transcript cleaned\n${RAW_LINES} -> ${CLEAN_LINES} lines\n$(basename "$OUTPUT")"
