#!/bin/bash
# Calendar events — fetches today's events via gws CLI, outputs markdown to stdout
# Called by obsidian_daily_notes.lua during daily note generation.

TODAY=$(date +%Y-%m-%d)
TOMORROW=$(date -d "$TODAY + 1 day" +%Y-%m-%d)
TZ_OFFSET=$(date +%:z)
GWS_DIR="$HOME/.config/gws/accounts/selfisheugenes"

# GPG decryption needs a TTY for pinentry
export GPG_TTY=$(tty)

# Calendars to query
CALENDARS=(
    "selfisheugenes@gmail.com"
    "4aa68da75eba9757ea4c7ada9892525cb985e3ecdafce2eaa47757d4b79c4901@group.calendar.google.com"
)

# Fetch events from all calendars, collect as JSON array
all_events="[]"
for cal_id in "${CALENDARS[@]}"; do
    raw=$(GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$GWS_DIR" \
        gws calendar events list --format json --params "$(jq -n \
            --arg calId "$cal_id" \
            --arg tMin "${TODAY}T00:00:00${TZ_OFFSET}" \
            --arg tMax "${TOMORROW}T00:00:00${TZ_OFFSET}" \
            '{calendarId: $calId, timeMin: $tMin, timeMax: $tMax, singleEvents: true, orderBy: "startTime"}'
        )" 2>/dev/null)

    items=$(echo "$raw" | jq '[(.items // [])[]]' 2>/dev/null)

    if [ -n "$items" ] && [ "$items" != "[]" ] && [ "$items" != "null" ]; then
        all_events=$(jq -s '.[0] + .[1]' <(echo "$all_events") <(echo "$items"))
    fi
done

if [ "$all_events" = "[]" ] || [ -z "$all_events" ]; then
    exit 0
fi

# Format events as markdown lines, sorted by start time
echo "$all_events" | jq -r '
  sort_by(.start.dateTime // .start.date) |
  .[] |
  (
    if .start.dateTime then
      (.start.dateTime[11:16]) + "-" + (.end.dateTime[11:16])
    elif .start.date then
      "All day"
    else
      "??:??"
    end
  ) as $time |
  (.summary // "Untitled") as $summary |
  "- \($time) -- \($summary)"
'
