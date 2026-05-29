#!/bin/bash
# Calendar events — fetches via google-workspace MCP (presto-ai), outputs markdown to stdout
# Called by obsidian_daily_notes.lua during daily note generation.
#
# Output format:
#   - HH:MM-HH:MM -- Summary
#   - All day -- Summary

TODAY=$(date +%Y-%m-%d)
TOMORROW=$(date -d "$TODAY + 1 day" +%Y-%m-%d)
TZ_OFFSET=$(date +%:z)
TMPFILE=$(mktemp /tmp/calendar-events-XXXXXX.json)

CALENDARS=(
    "selfisheugenes@gmail.com"
    "4aa68da75eba9757ea4c7ada9892525cb985e3ecdafce2eaa47757d4b79c4901@group.calendar.google.com"
)

# Build calendar list for the prompt
CAL_LIST=$(printf '"%s"\n' "${CALENDARS[@]}" | paste -sd, -)

# Fetch events via Claude + MCP; write combined items JSON array to TMPFILE
unset CLAUDECODE
timeout 30 claude -p \
    --permission-mode bypassPermissions \
    --allowedTools "mcp__google-workspace__calendar_listEvents,Write" \
    --model haiku \
    --no-session-persistence \
    "Fetch today's calendar events using the calendar_listEvents MCP tool.

Fetch from these two calendars (call the tool once per calendar):
1. selfisheugenes@gmail.com
2. 4aa68da75eba9757ea4c7ada9892525cb985e3ecdafce2eaa47757d4b79c4901@group.calendar.google.com

For each call use:
- calendarId: the calendar ID above
- timeMin: ${TODAY}T00:00:00${TZ_OFFSET}
- timeMax: ${TOMORROW}T00:00:00${TZ_OFFSET}

Merge all events from both calendars into a single JSON array. Each item must have keys: start (object with dateTime or date), end (object with dateTime or date), summary (string).

Write the JSON array to file: $TMPFILE

If no events found, write an empty array [].
Output nothing else." 2>/dev/null

# Format events using jq if file was written
if [ -f "$TMPFILE" ] && [ -s "$TMPFILE" ]; then
    jq -r '
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
    ' "$TMPFILE" 2>/dev/null
fi

rm -f "$TMPFILE"
