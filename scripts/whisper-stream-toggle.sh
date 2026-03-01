#!/usr/bin/env bash
#============================================================================
# Whisper Capture Toggle - System audio + mic → dual-transcript LLM merge
# F8: Start/stop recording both system audio and microphone
#      Transcribes each track separately with timestamps, then LLM merges
#      into a chronological dialog with speaker labels.
#============================================================================

PID_FILE="/tmp/whisper-stream.pid"
SYS_FILE="/tmp/whisper-capture-sys.wav"
MIC_FILE="/tmp/whisper-capture-mic.wav"
MODEL_DIR="$HOME/whisper-models"
TRANSCRIPTS_DIR="$HOME/Orthidian/transcripts"

# Model fallback: prefer medium.en, then small.en, then tiny.en
if [ -f "$MODEL_DIR/ggml-medium.en.bin" ]; then
    MODEL_PATH="$MODEL_DIR/ggml-medium.en.bin"
elif [ -f "$MODEL_DIR/ggml-small.en.bin" ]; then
    MODEL_PATH="$MODEL_DIR/ggml-small.en.bin"
else
    MODEL_PATH="$MODEL_DIR/ggml-tiny.en.bin"
fi

notify() { notify-send "Whisper" "$1" -t 3000; }

if [ -f "$PID_FILE" ]; then
    # --- STOP ---
    read -r SYS_PID MIC_PID < "$PID_FILE"
    kill "$SYS_PID" "$MIC_PID" 2>/dev/null
    wait "$SYS_PID" "$MIC_PID" 2>/dev/null
    rm -f "$PID_FILE"
    # Kill any orphaned pw-record capture processes (prevents PipeWire disruption)
    pkill -f "pw-record.*whisper-capture" 2>/dev/null || true

    if { [ -f "$SYS_FILE" ] && [ -s "$SYS_FILE" ]; } || { [ -f "$MIC_FILE" ] && [ -s "$MIC_FILE" ]; }; then
        mkdir -p "$TRANSCRIPTS_DIR"
        BASENAME="recording-$(date +%Y-%m-%d-%H%M)"
        FINAL_FILE="$TRANSCRIPTS_DIR/${BASENAME}.txt"

        notify "Transcribing ($(basename "$MODEL_PATH"))..."

        SYS_OUT="/tmp/whisper-out-sys.txt"
        MIC_OUT="/tmp/whisper-out-mic.txt"
        rm -f "$SYS_OUT" "$MIC_OUT"

        # Convert and transcribe both tracks in parallel
        if [ -s "$SYS_FILE" ]; then
            SYS_CONV="/tmp/whisper-capture-sys-conv.wav"
            ffmpeg -y -i "$SYS_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$SYS_CONV" 2>/dev/null
            whisper-cli -m "$MODEL_PATH" -t 6 -f "$SYS_CONV" > "$SYS_OUT" 2>/dev/null &
            SYS_WPID=$!
        fi
        if [ -s "$MIC_FILE" ]; then
            MIC_CONV="/tmp/whisper-capture-mic-conv.wav"
            ffmpeg -y -i "$MIC_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$MIC_CONV" 2>/dev/null
            whisper-cli -m "$MODEL_PATH" -t 6 -f "$MIC_CONV" > "$MIC_OUT" 2>/dev/null &
            MIC_WPID=$!
        fi

        # Wait for both to finish
        [ -n "${SYS_WPID:-}" ] && wait "$SYS_WPID"
        [ -n "${MIC_WPID:-}" ] && wait "$MIC_WPID"
        rm -f "$SYS_FILE" "$MIC_FILE" /tmp/whisper-capture-*-conv.wav

        SYS_TXT=""
        MIC_TXT=""
        [ -s "$SYS_OUT" ] && SYS_TXT=$(cat "$SYS_OUT")
        [ -s "$MIC_OUT" ] && MIC_TXT=$(cat "$MIC_OUT")
        rm -f "$SYS_OUT" "$MIC_OUT"

        # Combine transcripts with source labels
        {
            if [ -n "$SYS_TXT" ]; then
                echo "[System Audio]"
                echo "$SYS_TXT"
                echo ""
            fi
            if [ -n "$MIC_TXT" ]; then
                echo "[Mic]"
                echo "$MIC_TXT"
            fi
        } > "$FINAL_FILE"

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
        rm -f "$SYS_FILE" "$MIC_FILE"
    fi
else
    # --- START ---
    # Auto-detect default audio sink (system audio output)
    SINK_SERIAL=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'object.serial' | grep -oP '[0-9]+')
    if [ -z "$SINK_SERIAL" ]; then
        notify "Error: no default audio sink found"
        exit 1
    fi

    # Find echo-cancelled mic source (PipeWire AEC), fall back to raw default source
    EC_SERIAL=$(pw-cli ls Node 2>/dev/null | grep -B5 'echo-cancel-source' | grep 'id ' | grep -oP '[0-9]+' | tail -1)
    if [ -n "$EC_SERIAL" ]; then
        SOURCE_SERIAL="$EC_SERIAL"
        SOURCE_LABEL="Echo-Cancelled Mic"
    else
        SOURCE_SERIAL=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep 'object.serial' | grep -oP '[0-9]+')
        SOURCE_LABEL="Raw Mic (no echo cancel)"
    fi
    if [ -z "$SOURCE_SERIAL" ]; then
        notify "Error: no audio source found"
        exit 1
    fi

    SINK_NAME=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'node.description' | sed 's/.*= "\(.*\)"/\1/')

    # Kill any orphaned pw-record processes before starting fresh
    pkill -f "pw-record.*whisper-capture" 2>/dev/null || true
    sleep 0.2
    rm -f "$SYS_FILE" "$MIC_FILE"

    # Record system audio (what plays through speakers/AirPods)
    pw-record --target "$SINK_SERIAL" --rate 16000 --channels 1 "$SYS_FILE" &
    SYS_PID=$!

    # Record microphone (your voice)
    pw-record --target "$SOURCE_SERIAL" --rate 16000 --channels 1 "$MIC_FILE" &
    MIC_PID=$!

    echo "$SYS_PID $MIC_PID" > "$PID_FILE"

    notify "Recording system + mic...\nOutput: ${SINK_NAME:-sink $SINK_SERIAL}\nMic: ${SOURCE_LABEL}\nPress F8 to stop"
fi
