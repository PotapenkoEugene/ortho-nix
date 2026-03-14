#!/usr/bin/env bash
#============================================================================
# Transcript Polisher — claude -p fixes misrecognitions in clean transcripts
# Usage: polish-transcript.sh <clean-file> [output-file]
#
# Runs claude -p with a focused prompt to fix garbled words, wrong technical
# terms, and mangled proper nouns using surrounding context. Bioinformatics
# domain glossary included. Uncertain fixes kept in brackets.
#============================================================================
set -euo pipefail

INPUT="${1:?Usage: polish-transcript.sh <clean-file> [output-file]}"
BASENAME=$(basename "${INPUT%-clean.txt}")
OUTPUT="${2:-$(dirname "$INPUT")/${BASENAME}-polished.txt}"

notify() {
    notify-send "Transcript Polish" "$1" -t 5000 2>/dev/null || true
}

if [ ! -f "$INPUT" ]; then
    echo "Error: input file not found: $INPUT" >&2
    exit 1
fi

LINE_COUNT=$(wc -l < "$INPUT")
notify "Polishing transcript ($LINE_COUNT lines)..."

PROMPT='You are a transcript copy-editor. Fix clearly misrecognized words using surrounding context.

Domain glossary (bioinformatics): samtools, bcftools, bedtools, MACS2, MACS3, ChIP-seq, ATAC-seq, RNA-seq, WGS, BAM, CRAM, VCF, BED, FASTQ, FASTA, IGV, bowtie2, HISAT2, STAR, DESeq2, edgeR, Bioconductor, snakemake, nextflow, conda, micromamba, PipeWire, Vulkan, Nix, NixOS, nixpkgs, Home Manager, Neovim, tmux, Kitty, GNOME, Obsidian, Orthidian.

Rules:
- Fix obvious misrecognitions (e.g. "sam tools" -> "samtools", "chip seek" -> "ChIP-seq")
- If not confident in a correction, keep original and append fix in brackets: "sam tools [samtools]"
- Never add, remove, or rephrase content — only fix misrecognized words
- Preserve speaker labels (Me:, Other:) and paragraph structure exactly
- Output ONLY the corrected transcript, no commentary'

RESULT=$(timeout 300 claude -p "$PROMPT" --model sonnet --no-session-persistence --allowedTools "" < "$INPUT" 2>/dev/null) || {
    CODE=$?
    if [ "$CODE" -eq 124 ]; then
        notify "Polish failed (timeout)"
    else
        notify "Polish failed (exit code $CODE)"
    fi
    echo "Error: claude -p failed (exit code $CODE)" >&2
    exit 1
}

if [ -z "$RESULT" ]; then
    notify "Polish failed (empty output)"
    echo "Error: claude -p returned empty output" >&2
    exit 1
fi

echo "$RESULT" > "$OUTPUT"
POLISHED_LINES=$(wc -l < "$OUTPUT")

echo "Done: $LINE_COUNT -> $POLISHED_LINES lines"
echo "Output: $OUTPUT"

notify "Polished transcript saved\n${LINE_COUNT} -> ${POLISHED_LINES} lines\n$(basename "$OUTPUT")"
