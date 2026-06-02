#!/usr/bin/env bash
# Source script for the tmux-recent television channel.
# Emits: name<TAB><color>[Bucket]<reset>  per local tmux session.
# tv displays: colored label + name  (display = "{split:\t:1}  {split:\t:0}")
# tv outputs:  bare name only        (output  = "{split:\t:0}")
# so xargs tmux switch-client -t receives a clean session name.

NOW=$(date +%s)

# $'...' quoting produces actual tab chars — tmux does NOT interpret \t in -F strings
tmux ls -F $'#{session_attached}\t#{session_last_attached}\t#{session_name}' 2>/dev/null | \
awk -F'\t' -v now="$NOW" '
BEGIN {
    c_now   = "\033[1;32m"
    c_today = "\033[36m"
    c_week  = "\033[34m"
    c_month = "\033[33m"
    c_older = "\033[90m"
    r       = "\033[0m"
}
{
    attached = $1 + 0; last = $2 + 0; name = $3
    if (attached > 0) {
        c = c_now; b = "[Now]"; pri = 5
    } else {
        d = now - last
        if (last == 0 || d >= 2592000) { c = c_older; b = "[Older]"; pri = 4 }
        else if (d >= 604800)          { c = c_month; b = "[Month]"; pri = 3 }
        else if (d >= 86400)           { c = c_week;  b = "[Week]";  pri = 2 }
        else                           { c = c_today; b = "[Today]"; pri = 1 }
    }
    # pri<TAB>colored_label<TAB>name — sort on pri, then strip it before tv
    print pri "\t" c b r "\t" name
}
' | sort -t$'\t' -k1,1n | cut -f2-
