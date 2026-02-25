#!/usr/bin/env bash
# Toggle lofi radio stream on/off
STREAM_URL="https://play.streamafrica.net/lofiradio"

if pkill -f "ffplay.*lofiradio"; then
    notify-send "Lofi Radio" "Stopped" -t 2000
else
    ffplay -nodisp -loglevel quiet "$STREAM_URL" &
    disown
    notify-send "Lofi Radio" "Playing" -t 2000
fi
