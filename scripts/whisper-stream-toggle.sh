#!/usr/bin/env bash
#============================================================================
# Whisper Capture Toggle - System audio capture via PipeWire + batch transcription
# F8: Start/stop recording system audio (whatever plays through speakers/AirPods)
#============================================================================

PID_FILE="/tmp/whisper-stream.pid"
AUDIO_FILE="/tmp/whisper-capture.wav"
WHISPER_BIN="$HOME/Tools/whisper.cpp/build/bin/whisper-cli"
MODEL_PATH="$HOME/whisper-models/ggml-tiny.en.bin"
TRANSCRIPTS_DIR="$HOME/Orthidian/transcripts"

notify() { notify-send "Whisper" "$1" -t 3000; }

if [ -f "$PID_FILE" ]; then
    # --- STOP ---
    PID=$(cat "$PID_FILE")
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    rm -f "$PID_FILE"

    if [ -f "$AUDIO_FILE" ] && [ -s "$AUDIO_FILE" ]; then
        mkdir -p "$TRANSCRIPTS_DIR"
        BASENAME="recording-$(date +%Y-%m-%d-%H%M)"
        FINAL_FILE="$TRANSCRIPTS_DIR/${BASENAME}.txt"

        notify "Transcribing..."
        # Convert pw-record WAV to whisper-compatible format (pw-record headers aren't fully compatible)
        CONVERTED="/tmp/whisper-capture-converted.wav"
        ffmpeg -y -i "$AUDIO_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$CONVERTED" 2>/dev/null
        rm -f "$AUDIO_FILE"

        # Batch transcribe (more accurate than streaming)
        "$WHISPER_BIN" -m "$MODEL_PATH" -t 12 -f "$CONVERTED" --no-timestamps 2>/dev/null > "$FINAL_FILE"
        rm -f "$CONVERTED"

        if [ -s "$FINAL_FILE" ]; then
            notify "Saved: ${BASENAME}.txt\nCleaning..."
            clean-transcript.sh "$FINAL_FILE" &
            disown
        else
            notify "No speech detected"
            rm -f "$FINAL_FILE"
        fi
    else
        notify "No audio captured"
        rm -f "$AUDIO_FILE"
    fi
else
    # --- START ---
    # Auto-detect current default audio sink (need object.serial, not wpctl id)
    SINK_SERIAL=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'object.serial' | grep -oP '[0-9]+')
    if [ -z "$SINK_SERIAL" ]; then
        notify "Error: no default audio sink found"
        exit 1
    fi

    SINK_NAME=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'node.description' | sed 's/.*= "\(.*\)"/\1/')
    rm -f "$AUDIO_FILE"

    # Record system audio: 16kHz mono WAV (whisper format)
    pw-record --target "$SINK_SERIAL" --rate 16000 --channels 1 "$AUDIO_FILE" &
    echo $! > "$PID_FILE"

    notify "Recording system audio...\nSource: ${SINK_NAME:-sink $SINK_SERIAL}\nPress F8 to stop"
fi
