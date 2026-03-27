---
name: worktree
description: Manage git worktrees for parallel work — create, list, merge, and cleanup isolated workstreams
argument-hint: "create \"desc1\" [\"desc2\" ...] | list | merge <name> [--all]"
allowed-tools: Bash(git *), Bash(ls *), Bash(stat *), Bash(find *)
---

# Worktree Skill

Manages git worktrees as a parallelization scheme. Each worktree is an isolated checkout on its own branch — multiple Claude instances can work independently without conflicts.

## Subcommands

- `/worktree create "description one" "description two"` — create one or more worktrees
- `/worktree list` — show active worktrees with status
- `/worktree merge <name>` — squash-merge a worktree back to main and clean up
- `/worktree merge --all` — merge all worktrees sequentially

## Instructions

### Detect Subcommand

Parse the arguments to determine which subcommand to run:
- Starts with `create` → Create flow
- `list` (or no args) → List flow
- `merge --all` → Merge all flow
- `merge <name>` → Merge single flow

---

### Create Flow

For each description provided:

1. **Slugify** the description:
   - Lowercase, replace spaces and special chars with `-`
   - Truncate to 40 chars, strip leading/trailing `-`
   - Example: "shiny app appearance fixes" → `shiny-app-appearance-fixes`

2. **Check for conflicts:**
   ```bash
   git worktree list
   git branch --list "wt/<slug>"
   ```
   If branch or worktree already exists, report it and skip (don't fail the whole batch).

3. **Determine paths:**
   - Branch: `wt/<slug>`
   - Directory: `~/worktrees/<repo-name>/<slug>/`
   - Get repo name: `basename $(git rev-parse --show-toplevel)`

4. **Create:**
   ```bash
   git fetch origin main --quiet 2>/dev/null || true
   git worktree add ~/worktrees/<repo-name>/<slug> -b wt/<slug> main
   ```

5. **Report** for each created worktree:
   ```
   Created: wt/shiny-app-appearance-fixes
   Path:    ~/worktrees/home-manager/shiny-app-appearance-fixes/

   To start working:
     cd ~/worktrees/home-manager/shiny-app-appearance-fixes && claude
   ```

---

### List Flow

Run:
```bash
git worktree list --porcelain
```

For each worktree that has a `wt/` branch:
- Show branch name (without `wt/` prefix for readability)
- Commits ahead of main: `git rev-list main..wt/<slug> --count`
- Dirty status: `git -C <path> status --porcelain`
- Last modified: `stat -c %y <path>` (human-readable date)

Format output as a table:
```
Active worktrees:
  shiny-app-appearance-fixes   3 commits ahead   clean    ~/worktrees/home-manager/shiny-app-appearance-fixes/
  pipeline-batch-mode          1 commit ahead    dirty    ~/worktrees/home-manager/pipeline-batch-mode/
```

If no `wt/` worktrees exist, say so clearly.

---

### Merge Single Flow

Argument: `<name>` (the slug, with or without `wt/` prefix — normalize either way)

1. **Locate the worktree:**
   ```bash
   git worktree list --porcelain
   ```
   Find the worktree matching the slug. If not found, report error.

2. **Check for uncommitted changes:**
   ```bash
   git -C <worktree-path> status --porcelain
   ```
   If dirty:
   - Tell the user what files are changed/untracked
   - Ask: "The worktree has uncommitted changes. Options: (1) commit them first with /commit, (2) discard them and merge anyway, (3) cancel the merge."
   - Wait for user choice. If discard: `git -C <worktree-path> checkout -- . && git -C <worktree-path> clean -fd`
   - If cancel: stop.

3. **Check if anything to merge:**
   ```bash
   git rev-list main..wt/<slug> --count
   ```
   If 0 commits ahead, report "nothing to merge" and offer to just clean up the worktree.

4. **Summarize commits in the worktree:**
   ```bash
   git log main..wt/<slug> --oneline
   ```
   Show the user what will be squash-merged.

5. **Generate squash commit message:**
   - Analyze the commit list and changed files: `git diff main..wt/<slug> --stat`
   - Propose a Conventional Commits message:
     ```
     feat: <summary of what was done in the worktree>

     - <key change 1>
     - <key change 2>
     ```
   - Ask user to confirm or edit the message.

6. **Squash merge:**
   ```bash
   git merge --squash wt/<slug>
   ```
   If conflicts:
   - Show conflicting files
   - Help resolve them (read conflicting sections, propose resolution)
   - Do NOT force or discard — work through them with the user
   - After resolution: `git add <resolved-files>`

7. **Commit with confirmed message:**
   ```bash
   git commit -m "<confirmed message>"
   ```

8. **Push:**
   ```bash
   git push
   ```
   If no upstream: `git push -u origin main`

9. **Cleanup:**
   ```bash
   git worktree remove <worktree-path>
   git branch -d wt/<slug>
   ```

10. **Report success:**
    ```
    Merged wt/shiny-app-appearance-fixes into main (squash)
    Pushed to origin/main
    Cleaned up worktree and branch
    ```

---

### Merge All Flow

Run Merge Single Flow for each active `wt/` worktree, sequentially.

- On conflict or uncommitted changes: pause, resolve with user, then continue to next.
- Report a summary at the end: how many merged, any skipped.

---

## Rules

- **Never merge from inside a worktree.** If cwd is a worktree path, refuse and ask user to run from the main repo directory.
- **Never force push.** Never `git push --force`.
- **Never rewrite published history.**
- **Squash only** — all worktree commits become one commit on main. This keeps main history clean.
- **Branch prefix** `wt/` distinguishes worktree branches from regular work branches.
- **Base**: always branch from `main` HEAD, never from a dirty working tree.
