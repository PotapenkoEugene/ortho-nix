#!/usr/bin/env bash
#============================================================================
# Kitty Workspace — freeze/unfreeze tabs to focus on today's projects
#
# Frozen tabs are hidden from the tab bar and skipped by Ctrl+Tab navigation.
# All underlying tmux sessions stay running regardless of freeze state.
#
# Commands:
#   list           — print all tabs with [*]=active / [ ]=frozen (for TV source)
#   toggle [TITLE] — freeze if active, unfreeze if frozen (current tab if omitted)
#
# State file: ~/.config/kitty/workspaces/.frozen (one title per line)
#============================================================================

FROZEN_DIR="$HOME/.config/kitty/workspaces"
FROZEN_FILE="$FROZEN_DIR/.frozen"

mkdir -p "$FROZEN_DIR"
touch "$FROZEN_FILE"

# Ensure kitten can connect to Kitty — background launches lack KITTY_LISTEN_ON
if [ -z "$KITTY_LISTEN_ON" ]; then
    sock=$(ls /tmp/kitty-main-* 2>/dev/null | head -1)
    if [ -n "$sock" ]; then
        export KITTY_LISTEN_ON="unix:$sock"
    fi
fi

# ── helpers ──────────────────────────────────────────────────────────────────

_current_tab() {
    kitten @ ls 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
for osw in data:
    for tab in osw.get('tabs', []):
        if tab.get('is_focused'):
            print(tab.get('title', ''))
            sys.exit(0)
" 2>/dev/null
}

_get_all_tabs() {
    kitten @ ls 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
for osw in data:
    for tab in osw.get('tabs', []):
        t = tab.get('title', '')
        if t:
            print(t)
" 2>/dev/null
}

_re_escape() {
    printf '%s' "$1" | sed 's/[.+*?^${}()|[\]\\]/\\&/g'
}

_is_frozen() {
    grep -qxF "$1" "$FROZEN_FILE" 2>/dev/null
}

# ── apply filter ─────────────────────────────────────────────────────────────

_apply() {
    local frozen_count
    frozen_count=$(grep -c . "$FROZEN_FILE" 2>/dev/null) || frozen_count=0

    if [ "$frozen_count" -eq 0 ]; then
        # --ignore-overrides wipes accumulated runtime overrides. Using
        # `-o "tab_bar_filter="` alone adds an empty override on top of any
        # prior filter instead of replacing it, which leaves move_tab_forward
        # still operating on a stale filtered tab list.
        kitten @ load-config --ignore-overrides 2>/dev/null
        return
    fi

    local parts=()
    while IFS= read -r title; do
        [ -z "$title" ] && continue
        parts+=("title:^$(_re_escape "$title")\$")
    done < "$FROZEN_FILE"

    local expr
    if [ "${#parts[@]}" -eq 1 ]; then
        expr="not ${parts[0]}"
    else
        local joined
        joined=$(IFS=" or "; echo "${parts[*]}")
        expr="not ($joined)"
    fi

    kitten @ load-config --ignore-overrides -o "tab_bar_filter=$expr" 2>/dev/null
}

# ── list ─────────────────────────────────────────────────────────────────────

cmd_list() {
    while IFS= read -r title; do
        [ -z "$title" ] && continue
        if _is_frozen "$title"; then
            printf '[ ] %s\t%s\n' "$title" "$title"
        else
            printf '[*] %s\t%s\n' "$title" "$title"
        fi
    done < <(_get_all_tabs)
}

# ── toggle ───────────────────────────────────────────────────────────────────

cmd_toggle() {
    # Capture current focused tab upfront (before any switch)
    local current_title
    current_title=$(_current_tab)

    local title="${1:-$current_title}"
    if [ -z "$title" ]; then
        echo "kitty-workspace: could not determine tab title" >&2
        exit 1
    fi

    if _is_frozen "$title"; then
        # Unfreeze: remove from frozen list
        grep -vxF "$title" "$FROZEN_FILE" | grep -v '^$' > "${FROZEN_FILE}.tmp"
        mv "${FROZEN_FILE}.tmp" "$FROZEN_FILE"
    else
        # Freeze: if hiding the currently focused tab, switch to neighbor first
        if [ "$title" = "$current_title" ]; then
            kitten @ action next_tab 2>/dev/null
        fi
        printf '%s\n' "$title" >> "$FROZEN_FILE"
    fi

    _apply
}

# ── dispatch ─────────────────────────────────────────────────────────────────

case "${1:-}" in
    list)   cmd_list ;;
    toggle) cmd_toggle "$2" ;;
    *)
        echo "Usage: kitty-workspace.sh {list|toggle [TITLE]}" >&2
        exit 1
        ;;
esac
