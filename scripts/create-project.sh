#!/usr/bin/env bash
#============================================================================
# Create Project Wizard
#
# Interactive: project name → Linux or Mac → GitHub? (optional) →
# create dir + tmux session → open tab
# Always: create Obsidian project note + .claude/CLAUDE.md active-project pointer
# GitHub=yes: private repo PotapenkoEugene/<name>, clone into dir
# GitHub=no: plain dir, no git
#
# Requires: gh (authenticated) for GitHub repos; ssh mac-studio for mac projects
#============================================================================
set -uo pipefail

SOCK="unix:/tmp/kitty-main"

# ── Helper: create Obsidian project note (idempotent) ────────────────────────
create_obsidian_note() {
	local proj="$1" note d t
	note="$HOME/Orthidian/projects/$proj.md"
	[ -f "$note" ] && return 0
	mkdir -p "$HOME/Orthidian/projects"
	d=$(date +%Y-%m-%d)
	t=$(date +%H:%M)
	cat >"$note" <<EOF
---
id: $proj
aliases: []
tags:
  - project
Date created: $d
Time created: $t
---

# $proj

## Summary


## Objectives
- [ ] Set up $proj

## Notes
EOF
}

# ── 1. Project name ──────────────────────────────────────────────────────────
echo -e "\033[1;35m──── New Project ────\033[0m"
echo ""
printf "Project name: "
read -r raw_name
raw_name="${raw_name// /-}" # spaces → hyphens
name=$(echo "$raw_name" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-_')
# display_name: case preserved, used for Obsidian note + .claude pointer
display_name=$(echo "$raw_name" | tr -cd '[:alnum:]-_')
[ -z "$display_name" ] && display_name="$name"
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
*)
	echo "Cancelled."
	sleep 1
	exit 0
	;;
esac

# ── 3. GitHub repo? ──────────────────────────────────────────────────────────
echo ""
printf "Create GitHub repo? [Y/n]: "
read -r gh_choice
case "$gh_choice" in
[Nn]*) GH=no ;;
*) GH=yes ;;
esac

CLONE_URL=""
if [ "$GH" = yes ]; then
	echo -e "\033[36mCreating private GitHub repo PotapenkoEugene/$name...\033[0m"
	if gh repo create "PotapenkoEugene/$name" --private 2>&1; then
		CLONE_URL="git@github.com:PotapenkoEugene/$name.git"
	else
		echo -e "\033[33mWarning: gh repo create failed — plain dir, no git.\033[0m"
		GH=no
		sleep 2
	fi
fi

# ── 4. Create dir + session + open tab ──────────────────────────────────────
if [[ "$machine" == *"Mac"* ]]; then
	echo -e "\033[36mSetting up ~/Projects/$name on mac-studio...\033[0m"
	if [ "$GH" = yes ]; then
		ssh mac-studio "
            mkdir -p ~/Projects &&
            GIT_SSH_COMMAND='ssh -i ~/.ssh/id_github_ed25519 -o IdentitiesOnly=yes' \
                git clone '$CLONE_URL' ~/Projects/$name &&
            tmux new-session -d -s '$name' -c ~/Projects/$name 2>/dev/null || true
        "
	else
		ssh mac-studio "
            mkdir -p ~/Projects/$name &&
            tmux new-session -d -s '$name' -c ~/Projects/$name 2>/dev/null || true
        "
	fi
	# drop .claude/CLAUDE.md active-project pointer on mac
	ssh mac-studio "mkdir -p ~/Projects/$name/.claude && \
      printf '## Active Obsidian Project\n- Project: %s\n- File: ~/Orthidian/projects/%s.md\n' \
      '$display_name' '$display_name' > ~/Projects/$name/.claude/CLAUDE.md"
	# create Obsidian note locally (vault is local; synced separately)
	create_obsidian_note "$display_name"
	echo -e "\033[1;32mDone! Opening mac-studio/$name\033[0m"
	sleep 0.5
	tab_title="mac_$name"
	printf '\033]2;%s\007' "$tab_title"
	exec mac-attach.sh "$name"
else
	echo -e "\033[36mSetting up ~/Documents/Projects/$name locally...\033[0m"
	mkdir -p "$HOME/Documents/Projects/$name"
	cd "$HOME/Documents/Projects/$name"
	if [ "$GH" = yes ]; then
		GIT_SSH_COMMAND='ssh -i ~/.ssh/id_github_ed25519 -o IdentitiesOnly=yes' \
			git clone "$CLONE_URL" .
	fi
	# (GitHub=no: plain dir, no git init)
	tmux new-session -d -s "$name" -c "$HOME/Documents/Projects/$name" 2>/dev/null || true
	# drop .claude/CLAUDE.md active-project pointer
	mkdir -p "$HOME/Documents/Projects/$name/.claude"
	[ -f "$HOME/Documents/Projects/$name/.claude/CLAUDE.md" ] ||
		printf '## Active Obsidian Project\n- Project: %s\n- File: ~/Orthidian/projects/%s.md\n' \
			"$display_name" "$display_name" >"$HOME/Documents/Projects/$name/.claude/CLAUDE.md"
	# create Obsidian note
	create_obsidian_note "$display_name"
	echo -e "\033[1;32mDone! Opening $name\033[0m"
	sleep 0.5
	if kitten @ --to "$SOCK" focus-tab --match "title:$name" 2>/dev/null; then
		exit 0
	fi
	printf '\033]2;%s\007' "$name"
	exec kitty-tab-launch.sh "$name"
fi
