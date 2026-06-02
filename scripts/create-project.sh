#!/usr/bin/env bash
#============================================================================
# Create Project Wizard
#
# Interactive: project name → Linux or Mac → create dir + tmux session +
# private GitHub repo (PotapenkoEugene/<name>) → open tab
#
# Requires: gh (authenticated), ssh mac-studio reachable for mac projects
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"

# ── 1. Project name ──────────────────────────────────────────────────────────
echo -e "\033[1;35m──── New Project ────\033[0m"
echo ""
printf "Project name: "
read -r raw_name
raw_name="${raw_name// /-}"   # spaces → hyphens
name=$(echo "$raw_name" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
if [ -z "$name" ]; then
    echo "Cancelled."
    sleep 1
    exit 0
fi

# ── 2. Target machine ────────────────────────────────────────────────────────
echo "  1) Linux (local)"
echo "  2) Mac (mac-studio)"
printf "Machine [1/2]: "
read -r choice
case "$choice" in
    2) machine="Mac" ;;
    1) machine="Linux" ;;
    *) echo "Cancelled."; sleep 1; exit 0 ;;
esac

# ── 3. Create GitHub repo ────────────────────────────────────────────────────
echo ""
echo -e "\033[36mCreating private GitHub repo PotapenkoEugene/$name...\033[0m"
if gh repo create "PotapenkoEugene/$name" --private 2>&1; then
    GH_OK=true
    CLONE_URL="git@github.com:PotapenkoEugene/$name.git"
else
    GH_OK=false
    echo -e "\033[33mWarning: gh repo create failed — continuing without GitHub repo.\033[0m"
    sleep 2
fi

# ── 4. Create dir + session + open tab ──────────────────────────────────────
if [[ "$machine" == *"Mac"* ]]; then
    echo -e "\033[36mSetting up ~/Projects/$name on mac-studio...\033[0m"
    if [ "$GH_OK" = true ]; then
        ssh mac-studio "
            mkdir -p ~/Projects &&
            GIT_SSH_COMMAND='ssh -i ~/.ssh/id_github_ed25519 -o IdentitiesOnly=yes' \
                git clone '$CLONE_URL' ~/Projects/$name &&
            tmux new-session -d -s '$name' -c ~/Projects/$name 2>/dev/null || true
        "
    else
        ssh mac-studio "
            mkdir -p ~/Projects/$name &&
            cd ~/Projects/$name && git init &&
            tmux new-session -d -s '$name' -c ~/Projects/$name 2>/dev/null || true
        "
    fi
    echo -e "\033[1;32mDone! Opening mac-studio/$name\033[0m"
    sleep 0.5
    tab_title="mac_$name"
    printf '\033]2;%s\007' "$tab_title"
    exec mac-attach.sh "$name"
else
    echo -e "\033[36mSetting up ~/Projects/$name locally...\033[0m"
    mkdir -p "$HOME/Projects/$name"
    cd "$HOME/Projects/$name"
    if [ "$GH_OK" = true ]; then
        GIT_SSH_COMMAND='ssh -i ~/.ssh/id_github_ed25519 -o IdentitiesOnly=yes' \
            git clone "$CLONE_URL" .
    else
        git init
    fi
    tmux new-session -d -s "$name" -c "$HOME/Projects/$name" 2>/dev/null || true
    echo -e "\033[1;32mDone! Opening $name\033[0m"
    sleep 0.5
    if kitten @ --to "$SOCK" focus-tab --match "title:$name" 2>/dev/null; then
        exit 0
    fi
    printf '\033]2;%s\007' "$name"
    exec kitty-tab-launch.sh "$name"
fi
