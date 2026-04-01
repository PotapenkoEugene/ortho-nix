#!/usr/bin/env bash
#============================================================================
# Whisper Capture Toggle - System audio + mic → dual-transcript merge
# F8: Start/stop recording both system audio and microphone
#      Transcribes each track via Groq API (whisper-large-v3-turbo),
#      merges into a chronological dialog with speaker labels.
#============================================================================

PID_FILE="/tmp/whisper-stream.pid"
SYS_FILE="/tmp/whisper-capture-sys.wav"
MIC_FILE="/tmp/whisper-capture-mic.wav"
TRANSCRIPTS_DIR="$HOME/Orthidian/transcripts"

notify() { notify-send "Whisper" "$1" -t 3000; }

if [ -f "$PID_FILE" ]; then
    # --- STOP ---
    read -r SYS_PID MIC_PID REC_PID < "$PID_FILE"
    kill "$SYS_PID" "$MIC_PID" 2>/dev/null
    [ -n "${REC_PID:-}" ] && kill "$REC_PID" 2>/dev/null
    wait "$SYS_PID" "$MIC_PID" 2>/dev/null
    rm -f "$PID_FILE"
    # Kill any orphaned pw-record capture processes (prevents PipeWire disruption)
    pkill -f "pw-record.*whisper-capture" 2>/dev/null || true

    if { [ -f "$SYS_FILE" ] && [ -s "$SYS_FILE" ]; } || { [ -f "$MIC_FILE" ] && [ -s "$MIC_FILE" ]; }; then
        mkdir -p "$TRANSCRIPTS_DIR"
        BASENAME="recording-$(date +%Y-%m-%d-%H%M)"
        FINAL_FILE="$TRANSCRIPTS_DIR/${BASENAME}.txt"

        # Load GROQ_API_KEY from secrets
        # shellcheck source=/dev/null
        [ -f "$HOME/.secrets/env" ] && source "$HOME/.secrets/env"
        if [ -z "${GROQ_API_KEY:-}" ]; then
            notify "Error: GROQ_API_KEY not set in ~/.secrets/env"
            rm -f "$SYS_FILE" "$MIC_FILE"
            exit 1
        fi

        notify "Transcribing (Groq API)..."

        SYS_JSON="/tmp/whisper-out-sys.json"
        MIC_JSON="/tmp/whisper-out-mic.json"
        rm -f "$SYS_JSON" "$MIC_JSON"

        # Transcribe one track via Groq API: WAV → FLAC → API → JSON
        transcribe_groq() {
            local audio_file="$1" json_out="$2"
            local flac_file="${audio_file%.wav}.flac"
            ffmpeg -y -i "$audio_file" -ar 16000 -ac 1 "$flac_file" 2>/dev/null
            local http_code
            http_code=$(curl -s -o "$json_out" -w "%{http_code}" \
                https://api.groq.com/openai/v1/audio/transcriptions \
                -H "Authorization: Bearer $GROQ_API_KEY" \
                -F "file=@${flac_file}" \
                -F "model=whisper-large-v3-turbo" \
                -F "response_format=verbose_json")
            rm -f "$flac_file"
            if [ "$http_code" != "200" ]; then
                notify "Groq API error ($http_code) — check GROQ_API_KEY"
                return 1
            fi
        }

        # Transcribe both tracks in parallel
        if [ -s "$SYS_FILE" ]; then
            transcribe_groq "$SYS_FILE" "$SYS_JSON" &
            SYS_WPID=$!
        fi
        if [ -s "$MIC_FILE" ]; then
            transcribe_groq "$MIC_FILE" "$MIC_JSON" &
            MIC_WPID=$!
        fi

        [ -n "${SYS_WPID:-}" ] && wait "$SYS_WPID"
        [ -n "${MIC_WPID:-}" ] && wait "$MIC_WPID"
        rm -f "$SYS_FILE" "$MIC_FILE"

        # Extract timestamped lines from JSON: [5.12s --> 10.44s] text
        SYS_TXT=""
        MIC_TXT=""
        [ -s "$SYS_JSON" ] && SYS_TXT=$(jq -r '.segments[] | "[\(.start)s --> \(.end)s] \(.text)"' "$SYS_JSON" 2>/dev/null)
        [ -s "$MIC_JSON" ] && MIC_TXT=$(jq -r '.segments[] | "[\(.start)s --> \(.end)s] \(.text)"' "$MIC_JSON" 2>/dev/null)
        rm -f "$SYS_JSON" "$MIC_JSON"

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
            CLEAN_FILE="$TRANSCRIPTS_DIR/${BASENAME}-clean.txt"
            (
                clean-transcript.sh "$FINAL_FILE" "$CLEAN_FILE"
                if [ -f "$CLEAN_FILE" ] && [ -s "$CLEAN_FILE" ]; then
                    polish-transcript.sh "$CLEAN_FILE"
                fi
            ) &
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

    # Show red REC indicator in top-right corner
    echo " ● REC " | yad --text-info \
        --no-buttons --undecorated --on-top --sticky --skip-taskbar \
        --no-focus --width=40 --height=45 \
        --geometry=+1820+5 \
        --back='#cc0000' --fore='#ffffff' \
        --fontname='Bold 16' &
    REC_PID=$!

    echo "$SYS_PID $MIC_PID $REC_PID" > "$PID_FILE"

    notify "Recording system + mic...\nOutput: ${SINK_NAME:-sink $SINK_SERIAL}\nMic: ${SOURCE_LABEL}\nPress F8 to stop"
fi
