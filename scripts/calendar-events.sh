#!/bin/bash
# Calendar events + tasks — fetches via gws CLI, outputs markdown to stdout
# Called by obsidian_daily_notes.lua during daily note generation.
#
# Output format:
#   - HH:MM-HH:MM -- Summary
#   - All day -- Summary
#   ---TASKS---
#   - [ ] Task title
#   - [ ] Another task

TODAY=$(date +%Y-%m-%d)
TOMORROW=$(date -d "$TODAY + 1 day" +%Y-%m-%d)
TZ_OFFSET=$(date +%:z)
GWS_DIR="$HOME/.config/gws/accounts/selfisheugenes"

# GPG decryption needs a TTY for pinentry
export GPG_TTY=$(tty)

# --- Calendar Events ---

CALENDARS=(
    "selfisheugenes@gmail.com"
    "4aa68da75eba9757ea4c7ada9892525cb985e3ecdafce2eaa47757d4b79c4901@group.calendar.google.com"
)

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

# Output events sorted by start time
if [ "$all_events" != "[]" ] && [ -n "$all_events" ]; then
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
fi

# --- Google Tasks ---

echo "---TASKS---"

# Get default tasklist ID
tasklist_id=$(GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$GWS_DIR" \
    gws tasks tasklists list --format json 2>/dev/null \
    | jq -r '.items[0].id // empty')

if [ -n "$tasklist_id" ]; then
    raw_tasks=$(GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$GWS_DIR" \
        gws tasks tasks list --format json --params "$(jq -n \
            --arg tl "$tasklist_id" \
            --arg dMin "${TODAY}T00:00:00Z" \
            --arg dMax "${TOMORROW}T00:00:00Z" \
            '{tasklist: $tl, showCompleted: false, dueMin: $dMin, dueMax: $dMax}'
        )" 2>/dev/null)

    if [ -n "$raw_tasks" ]; then
        echo "$raw_tasks" | jq -r '
          [(.items // [])[]] |
          sort_by(.due // "9999") |
          .[] |
          # Use title, fall back to notes if title is empty
          (if (.title // "") == "" then (.notes // "Untitled") else .title end) as $text |
          "- [ ] \($text)",
          # Output notes as indented line if title is non-empty and notes exist
          if (.title // "") != "" and (.notes // "") != "" then
            "    - \(.notes)"
          else
            empty
          end
        '
    fi
fi
