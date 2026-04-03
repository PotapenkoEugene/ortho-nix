#!/usr/bin/env bash
# Toggle lofi playlist via mpd/mpc
# Bound to Super+L in GNOME

export MPD_HOST="/run/user/1000/mpd.sock"
LOFI_DIR="lofi"
PAUSE_FILE="/tmp/lofi-paused-at"
ONE_HOUR=3600

notify() { notify-send "Lofi" "$1" -t 2000; }

if ! mpc status >/dev/null 2>&1; then
    notify "MPD not running"
    exit 1
fi

# Convert [H:]MM:SS to seconds
time_to_seconds() {
    IFS=: read -ra parts <<< "$1"
    case ${#parts[@]} in
        2) echo $(( 10#${parts[0]} * 60 + 10#${parts[1]} )) ;;
        3) echo $(( 10#${parts[0]} * 3600 + 10#${parts[1]} * 60 + 10#${parts[2]} )) ;;
        *) echo 0 ;;
    esac
}

# Seek to a random point within the current track (up to 85% through)
seek_random() {
    sleep 0.5
    DURATION_STR=$(mpc -f "%time%" current 2>/dev/null)
    DURATION=$(time_to_seconds "$DURATION_STR")
    if [ "$DURATION" -gt 120 ]; then
        MAX=$(( DURATION * 85 / 100 ))
        SEEK=$(shuf -i 0-"$MAX" -n 1)
        mpc seek "$SEEK" >/dev/null 2>&1
    fi
}

# Load lofi dir, shuffle, play from random point
start_fresh() {
    mpc update --wait "$LOFI_DIR" >/dev/null 2>&1
    mpc clear >/dev/null
    mpc ls "$LOFI_DIR" | mpc add 2>/dev/null
    COUNT=$(mpc playlist | wc -l)
    if [ "$COUNT" -eq 0 ]; then
        notify "No tracks in ~/Music/lofi/ — run lofi-dl to add some"
        exit 1
    fi
    mpc shuffle >/dev/null
    mpc play >/dev/null
    rm -f "$PAUSE_FILE"
    seek_random
}

STATE=$(mpc status "%state%" 2>/dev/null)
CURRENT=$(mpc current 2>/dev/null)

is_lofi() {
    [[ "$CURRENT" == lofi/* ]]
}

case "$STATE" in
    playing)
        if is_lofi; then
            mpc pause >/dev/null
            date +%s > "$PAUSE_FILE"
            notify "Paused"
        else
            start_fresh
            notify "Playing (shuffled)"
        fi
        ;;
    paused)
        if is_lofi; then
            PAUSED_AT=$(cat "$PAUSE_FILE" 2>/dev/null)
            NOW=$(date +%s)
            ELAPSED=$(( NOW - ${PAUSED_AT:-0} ))
            if [ "$PAUSED_AT" ] && [ "$ELAPSED" -lt "$ONE_HOUR" ]; then
                mpc play >/dev/null
                rm -f "$PAUSE_FILE"
                notify "Resumed"
            else
                start_fresh
                notify "Resumed (fresh start — paused too long)"
            fi
        else
            start_fresh
            notify "Playing (shuffled)"
        fi
        ;;
    *)
        start_fresh
        notify "Playing (shuffled)"
        ;;
esac
