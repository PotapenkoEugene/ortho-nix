#!/usr/bin/env bash
#============================================================================
# Whisper Stream Toggle - Start/Stop with one hotkey
#============================================================================

PID_FILE="/tmp/whisper-stream.pid"
OUTPUT_FILE="/tmp/whisper-stream-output.txt"
WHISPER_BIN="$HOME/Tools/whisper.cpp/build/bin/whisper-stream"
MODEL_PATH="$HOME/whisper-models/ggml-tiny.en.bin"
TRANSCRIPTS_DIR="$HOME/Orthidian/transcripts"

notify() {
    notify-send "Whisper Stream" "$1" -t 3000
}

# Check if recording is in progress
if [ -f "$PID_FILE" ]; then
    # Stop recording
    PID=$(cat "$PID_FILE")
    
    if kill -0 "$PID" 2>/dev/null; then
        # Kill all child processes first (including whisper-stream)
        pkill -P "$PID" 2>/dev/null || true

        # Also kill any whisper-stream by name (in case it escaped)
        pkill -f "whisper-stream.*ggml-tiny.en.bin" 2>/dev/null || true

        # Then kill the parent nix-shell process
        kill "$PID" 2>/dev/null || true
        sleep 1

        # Force kill everything if still running
        pkill -9 -P "$PID" 2>/dev/null || true
        pkill -9 -f "whisper-stream.*ggml-tiny.en.bin" 2>/dev/null || true
        kill -9 "$PID" 2>/dev/null || true
        
        # Save to final location
        mkdir -p "$TRANSCRIPTS_DIR"
        FINAL_FILE="$TRANSCRIPTS_DIR/recording-$(date +%Y-%m-%d-%H%M).txt"
        
        if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
            mv "$OUTPUT_FILE" "$FINAL_FILE"
            notify "Recording stopped\nSaved: $(basename "$FINAL_FILE")"
        else
            notify "Recording stopped\n(No transcription recorded)"
        fi
        
        rm -f "$PID_FILE"
    else
        rm -f "$PID_FILE"
        notify "No active recording found"
    fi
else
    # Start recording
    notify "Recording started... (Press F8 to stop)"
    
    # Clear previous output
    > "$OUTPUT_FILE"
    
    # Run whisper-stream in background with output to file
    nix-shell -p SDL2 --run "$WHISPER_BIN -m $MODEL_PATH -t 12 --step 0 --length 30000 -vth 0.6 -ng -f $OUTPUT_FILE" &>/dev/null &
    
    echo $! > "$PID_FILE"
fi
