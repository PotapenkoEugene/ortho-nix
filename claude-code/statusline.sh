#!/usr/bin/env bash
# Claude Code Status Line - Powerline with gradient bars
# Shows: user | dir | git | model | vim | agent | [ctx bar] | [compactions] | [duration] | [5h bar] | [7d bar]

input=$(cat)

# --- Single jq extraction (use _ as placeholder for empty fields) ---
IFS=$'\t' read -r model cwd output_style vim_mode agent ctx_size used_pct session_id \
  input_tok cache_create_tok cache_read_tok < <(
  echo "$input" | jq -r '[
    (.model.display_name // "_"),
    (.workspace.current_dir // "_"),
    (.output_style.name // "_"),
    (.vim.mode // "_"),
    (.agent.name // "_"),
    (.context_window.context_window_size // 200000),
    (.context_window.used_percentage // 0),
    (.session_id // "_"),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.cache_creation_input_tokens // 0),
    (.context_window.current_usage.cache_read_input_tokens // 0)
  ] | @tsv'
)

# Normalize placeholders to empty
[[ "$model" == "_" ]] && model=""
[[ "$cwd" == "_" ]] && cwd=""
[[ "$output_style" == "_" ]] && output_style=""
[[ "$vim_mode" == "_" ]] && vim_mode=""
[[ "$agent" == "_" ]] && agent=""
[[ "$session_id" == "_" ]] && session_id=""

# Fix context window size for 1M models
if [[ "$model" == *"Opus 4.6"* || "$model" == *"Sonnet 4.6"* ]]; then
  ctx_size=1000000
fi

# --- Token computation ---
total_tokens=$(( input_tok + cache_create_tok + cache_read_tok ))
# Fallback to percentage-derived if token fields are 0
if (( total_tokens == 0 )); then
  total_tokens=$(( ctx_size * used_pct / 100 ))
fi

# --- State tracking (compaction + session start) ---
STATE_FILE="/tmp/claude-statusline-${session_id}"
compact_count=0
prev_pct=0

if [ -n "$session_id" ] && [ -f "$STATE_FILE" ]; then
  read -r prev_pct compact_count < "$STATE_FILE" 2>/dev/null
  compact_count=${compact_count:-0}
  prev_pct=${prev_pct:-0}
  # Guard against corrupted state (non-numeric values)
  [[ "$compact_count" =~ ^[0-9]+$ ]] || compact_count=0
  [[ "$prev_pct" =~ ^[0-9]+$ ]] || prev_pct=0
  if [ "$prev_pct" -gt 0 ] && [ $(( prev_pct - used_pct )) -gt 20 ]; then
    compact_count=$(( compact_count + 1 ))
  fi
fi
if [ -n "$session_id" ]; then
  echo "$used_pct $compact_count" > "$STATE_FILE"
fi

# --- Derived values ---
user=$(whoami)
short_dir="${cwd/#$HOME/\~}"

# Git branch + status
git_branch=""
git_status=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -n "$git_branch" ]; then
    has_staged=$(git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null; echo $?)
    has_unstaged=$(git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null; echo $?)
    has_untracked=$(git -C "$cwd" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null | grep -q .; echo $?)
    if [ "$has_staged" -ne 0 ]; then
      git_status="+"
    elif [ "$has_unstaged" -ne 0 ]; then
      git_status="*"
    elif [ "$has_untracked" -eq 0 ]; then
      git_status="?"
    fi
  fi
fi

now=$(date +%s)

# --- API usage (cached, background fetch) ---
USAGE_CACHE="/tmp/claude-usage-cache"
USAGE_TTL=300
five_hour=""
seven_day=""
five_hour_resets=""
seven_day_resets=""

fetch_usage() {
  local creds="$HOME/.claude/.credentials.json"
  [ -f "$creds" ] || return 1
  local token
  token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
  [ -n "$token" ] || return 1
  local resp
  resp=$(curl -sf --max-time 5 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
  [ -n "$resp" ] || return 1
  local f5 f7 r5 r7
  IFS=$'\t' read -r f5 f7 r5 r7 < <(echo "$resp" | jq -r '[
    (.five_hour.utilization // 0 | floor),
    (.seven_day.utilization // 0 | floor),
    (.five_hour.resets_at // "_"),
    (.seven_day.resets_at // "_")
  ] | @tsv')
  # Convert ISO timestamps to epoch
  local r5e=0 r7e=0
  [[ "$r5" != "_" ]] && r5e=$(date -d "$r5" +%s 2>/dev/null || echo 0)
  [[ "$r7" != "_" ]] && r7e=$(date -d "$r7" +%s 2>/dev/null || echo 0)
  local tmpf="${USAGE_CACHE}.tmp"
  echo "$(date +%s) $f5 $f7 $r5e $r7e" > "$tmpf" && mv "$tmpf" "$USAGE_CACHE"
}

if [ -f "$USAGE_CACHE" ]; then
  read -r cache_ts five_hour seven_day five_hour_resets seven_day_resets < "$USAGE_CACHE" 2>/dev/null
  five_hour=${five_hour%.*}
  seven_day=${seven_day%.*}
  five_hour_resets=${five_hour_resets:-0}
  seven_day_resets=${seven_day_resets:-0}
  age=$(( now - cache_ts ))
  if (( age > USAGE_TTL )); then
    fetch_usage &
  fi
else
  fetch_usage &
fi

# Compute elapsed time in each window (rolling: elapsed = window - remaining)
five_hour_elapsed=""
seven_day_elapsed=""
if (( five_hour_resets > 0 )); then
  remaining_5h=$(( five_hour_resets - now ))
  (( remaining_5h < 0 )) && remaining_5h=0
  elapsed_5h=$(( 18000 - remaining_5h ))  # 5h = 18000s
  (( elapsed_5h < 0 )) && elapsed_5h=0
  # Format as X.Xh (tenths of hours)
  eh=$(( elapsed_5h / 3600 ))
  em=$(( (elapsed_5h % 3600) / 360 ))  # tenths of hour
  five_hour_elapsed="${eh}.${em}"
fi
if (( seven_day_resets > 0 )); then
  remaining_7d=$(( seven_day_resets - now ))
  (( remaining_7d < 0 )) && remaining_7d=0
  elapsed_7d=$(( 604800 - remaining_7d ))  # 7d = 604800s
  (( elapsed_7d < 0 )) && elapsed_7d=0
  # Format as Xd (whole days, with tenths)
  ed=$(( elapsed_7d / 86400 ))
  et=$(( (elapsed_7d % 86400) / 8640 ))  # tenths of day
  seven_day_elapsed="${ed}.${et}"
fi

# --- ANSI codes (pre-rendered via $'...' for immediate use) ---
C_RESET=$'\033[0m'
FG_BRIGHT=$'\033[97m'
FG_BLACK=$'\033[30m'
FG_DIM=$'\033[38;5;242m'

BG_USER=$'\033[48;5;24m'
BG_DIR=$'\033[48;5;22m'
BG_GIT_CLEAN=$'\033[48;5;28m'
BG_GIT_DIRTY=$'\033[48;5;3m'
BG_GIT_STAGED=$'\033[48;5;53m'
BG_MODEL=$'\033[48;5;25m'
BG_VIM=$'\033[48;5;58m'
BG_AGENT=$'\033[48;5;88m'
BG_BAR=$'\033[48;5;236m'

# Bar fill colors (foreground for block chars)
FG_GREEN=$'\033[38;5;34m'
FG_YELLOW=$'\033[38;5;220m'
FG_ORANGE=$'\033[38;5;208m'
FG_RED=$'\033[38;5;196m'
FG_EMPTY=$'\033[38;5;240m'

# Bar fill colors (background for text-on-bar)
BG_GREEN=$'\033[48;5;34m'
BG_YELLOW=$'\033[48;5;220m'
BG_ORANGE=$'\033[48;5;208m'
BG_RED=$'\033[48;5;196m'

# Compaction counter backgrounds
BG_COMPACT_0=$'\033[48;5;22m'
BG_COMPACT_1=$'\033[48;5;28m'
BG_COMPACT_2=$'\033[48;5;3m'
BG_COMPACT_3=$'\033[48;5;1m'

# Unicode chars
CHAR_FILL=$'\xe2\x96\x88'   # █
CHAR_EMPTY=$'\xe2\x96\x91'  # ░
CHAR_DOT=$'\xc2\xb7'        # ·
CHAR_CYCLE=$'\xe2\x9f\xb3'  # ⟳

# --- Helpers ---
block() {
  printf '%s' "${1}${2} ${3} ${C_RESET}"
}

format_tokens() {
  local t=$1
  if (( t >= 1000000 )); then
    printf "%d.%dM" "$(( t / 1000000 ))" "$(( (t % 1000000) / 100000 ))"
  elif (( t >= 1000 )); then
    printf "%dk" "$(( t / 1000 ))"
  else
    printf "%d" "$t"
  fi
}

# Gradient fill bar: pct width -> bar string using block chars
gradient_bar() {
  local pct=$1 width=$2
  local filled=$(( pct * width / 100 ))
  (( pct > 0 && filled == 0 )) && filled=1
  (( filled > width )) && filled=$width
  local empty=$(( width - filled ))

  local fg
  if (( pct >= 80 )); then fg="$FG_RED"
  elif (( pct >= 65 )); then fg="$FG_ORANGE"
  elif (( pct >= 40 )); then fg="$FG_YELLOW"
  else fg="$FG_GREEN"
  fi

  local bar=""
  if (( filled > 0 )); then
    bar+="$fg"
    for (( i=0; i<filled; i++ )); do bar+="$CHAR_FILL"; done
  fi
  if (( empty > 0 )); then
    bar+="$FG_EMPTY"
    for (( i=0; i<empty; i++ )); do bar+="$CHAR_EMPTY"; done
  fi
  printf '%s' "$bar"
}

# Text-on-bar: renders label text with filled bg / empty bg split
# Usage: text_bar "4.3/5h" 47
# Chars up to the fill point get colored bg, rest get dark bg
text_bar() {
  local label="$1" pct=$2
  local len=${#label}
  local filled=$(( pct * len / 100 ))
  (( pct > 0 && filled == 0 )) && filled=1
  (( filled > len )) && filled=$len

  # Pick bg color by percentage
  local bg
  if (( pct >= 80 )); then bg="$BG_RED"
  elif (( pct >= 65 )); then bg="$BG_ORANGE"
  elif (( pct >= 40 )); then bg="$BG_YELLOW"
  else bg="$BG_GREEN"
  fi

  # Text color: black on colored bg for contrast, light gray on dark bg
  local fg_filled="$FG_BLACK"
  # Use white text on dark backgrounds (red, green)
  if (( pct >= 80 )); then fg_filled="$FG_BRIGHT"  # white on red
  elif (( pct < 40 )); then fg_filled="$FG_BRIGHT"  # white on green
  fi
  local fg_empty=$'\033[38;5;250m'  # light gray on dark bg

  local result=""
  local i
  for (( i=0; i<len; i++ )); do
    local ch="${label:i:1}"
    if (( i < filled )); then
      result+="${bg}${fg_filled}${ch}"
    else
      result+="${BG_BAR}${fg_empty}${ch}"
    fi
  done
  printf '%s' "$result"
}

# --- Build output ---
output=""

# User
output+="$(block "$BG_USER" "$FG_BRIGHT" "$user")"

# Directory
output+="$(block "$BG_DIR" "$FG_BRIGHT" "$short_dir")"

# Git
if [ -n "$git_branch" ]; then
  if [ "$git_status" = "+" ]; then
    git_bg="$BG_GIT_STAGED"; git_fg="$FG_BRIGHT"
  elif [ -n "$git_status" ]; then
    git_bg="$BG_GIT_DIRTY"; git_fg="$FG_BLACK"
  else
    git_bg="$BG_GIT_CLEAN"; git_fg="$FG_BRIGHT"
  fi
  local_status="${git_branch}${git_status:+ $git_status}"
  output+="$(block "$git_bg" "$git_fg" " $local_status")"
fi

# Model
short_model="${model/Claude /}"
output+="$(block "$BG_MODEL" "$FG_BRIGHT" "$short_model")"

# Vim mode
if [ -n "$vim_mode" ]; then
  output+="$(block "$BG_VIM" "$FG_BRIGHT" "[$vim_mode]")"
fi

# Agent
if [ -n "$agent" ]; then
  output+="$(block "$BG_AGENT" "$FG_BRIGHT" "$agent")"
fi

# Compaction counter (before context bar)
if [ "$compact_count" -ge 3 ]; then
  cmp_bg="$BG_COMPACT_3"; cmp_fg="$FG_BRIGHT"
elif [ "$compact_count" -ge 2 ]; then
  cmp_bg="$BG_COMPACT_2"; cmp_fg="$FG_BLACK"
elif [ "$compact_count" -ge 1 ]; then
  cmp_bg="$BG_COMPACT_1"; cmp_fg="$FG_BRIGHT"
else
  cmp_bg="$BG_COMPACT_0"; cmp_fg="$FG_BRIGHT"
fi
output+="$(block "$cmp_bg" "$cmp_fg" "${CHAR_CYCLE}${compact_count}")"

# Context: text-on-bar (static label, API percentage for fill)
ctx_pct=${used_pct:-0}
output+="$(text_bar " 1M " "$ctx_pct")${C_RESET}"

# 5-hour usage: text-on-bar
if [ -n "$five_hour" ]; then
  output+="$(text_bar " 5h " "$five_hour")${C_RESET}"
else
  output+="${BG_BAR}${FG_DIM} 5h ${C_RESET}"
fi

# 7-day usage: text-on-bar
if [ -n "$seven_day" ]; then
  output+="$(text_bar " 7d " "$seven_day")${C_RESET}"
else
  output+="${BG_BAR}${FG_DIM} 7d ${C_RESET}"
fi

printf '%s\n' "$output"
