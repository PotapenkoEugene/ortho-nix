---
name: commit
description: Stage, commit, and push changes with gitignore hygiene checks and Conventional Commits messages
argument-hint: "[\"optional commit message\"]"
allowed-tools: Bash(git *), Bash(find *), Bash(stat *), Bash(ls *), Bash(du *)
---

# Commit Skill

Handles the full commit workflow: gitignore hygiene → stage → commit message → commit → push. Works in both the main repo and worktrees.

## Usage

- `/commit` — full auto flow
- `/commit "message"` — use provided message (still runs hygiene check)

## Instructions

### Step 1: Gitignore Hygiene Check

Run:
```bash
git status --porcelain
git ls-files --others --exclude-standard
```

**Scan untracked files against these patterns** (check each untracked file):

| Category | Patterns to flag |
|----------|-----------------|
| Large files | Any file >1MB (`du -b <file>`) |
| Nix build | `result`, `result-*`, `result/` |
| Build artifacts | `dist/`, `build/`, `*.o`, `*.so`, `*.dylib` |
| Editor/IDE | `.idea/`, `.vscode/`, `*.swp`, `*~`, `.DS_Store` |
| Python | `__pycache__/`, `*.pyc`, `*.pyo`, `.pytest_cache/`, `*.egg-info/` |
| R | `.Rhistory`, `.RData`, `.Rproj.user/` |
| Node | `node_modules/` |
| Models/media | `*.gguf`, `*.bin >1MB`, `*.wav`, `*.mp3`, `*.mp4` |
| Secrets | `.env`, `.env.*`, `*secret*`, `*credential*`, `*.pem`, `*.key`, `*token*` |
| Tool caches | `.playwright-cli/`, `.cache/`, `*.log` |
| Data files | `*.csv >1MB`, `*.tsv >1MB`, `*.parquet`, `*.sqlite`, `*.db` |

**Also check existing `.gitignore`** for missing common patterns. For a Nix/home-manager repo, suggest these if absent:
- `result`
- `.playwright-cli/`
- `*.log`

**For each flagged item:**
- **Secrets/credentials**: warn loudly, strongly recommend gitignore, never commit these
- **Large files/models/data**: recommend gitignore
- **Build artifacts/caches**: recommend gitignore
- **Uncertain files**: ask the user — "Found `foo.dat` (2.3MB) — should this be gitignored?"

If any additions needed, show the proposed `.gitignore` additions and ask:
> "Add these to .gitignore before committing? (yes/no/edit)"

If yes: append to `.gitignore`, stage it as part of the commit.

---

### Step 2: Understand What Changed

```bash
git status
git diff --stat HEAD
git diff HEAD
```

Use the **current conversation context** (what was just built, discussed, or worked on) along with the diff to understand the intent behind each changed file. This makes grouping accurate — you know *why* each file changed, not just *that* it changed.

**Group changes into logical commits:**

A logical group = files that belong to the same feature, fix, or concern. Examples of good groups:
- All files adding a new skill (SKILL.md + claude-code.nix entry + settings.json permission)
- All files fixing a specific bug
- A package addition (packages.nix line + any supporting config)

Separate groups when changes are unrelated — e.g., "add R packages" and "fix gnome sleep settings" should be different commits even if both touch `modules/`.

**If multiple groups exist:**

1. Present the proposed grouping to the user:
   ```
   Found 3 logical groups:
   1. feat(claude-code): add /worktree and /commit skills
      → claude-code/CLAUDE.md, settings.json, claude-code.nix, skills/worktree/SKILL.md, skills/commit/SKILL.md
   2. chore(nix): migrate playwright-mcp to playwright-cli
      → packages.nix, flake.nix, packages/playwright-cli/package.nix, .gitignore
   3. chore(gnome): disable sleep/idle on AC power
      → modules/gnome.nix

   Commit all 3 in order? (yes / edit grouping / pick specific ones)
   ```

2. Wait for confirmation. User can: approve all, reorder, merge groups, or skip some.

3. **Execute as a loop** — for each confirmed group in order:
   - Stage the specific files for that group
   - Propose commit message (or use the one already shown)
   - Ask for confirmation: "Commit 1/3: `feat(claude-code): add /worktree and /commit skills` — OK?"
   - Commit
   - Push
   - Report success, then move to next group

**If only one logical group:** skip the grouping presentation, go straight to staging.

**If user provided a message as argument (`/commit "message"`):** treat all changes as one group with that message. Still show which files will be staged and ask confirmation.

---

### Commit Message Format

**Conventional Commits:**
```
<type>(<optional scope>): <short summary>

<optional body: bullet points of key changes>
```

Types: `feat` (new feature), `fix` (bug fix), `refactor` (restructure without behavior change), `chore` (tooling, config, deps), `docs` (documentation only), `style` (formatting)

Examples:
- `feat(worktree): add squash merge with cleanup`
- `chore(nix): add playwright-cli derivation to flake overlay`
- `fix(shell): correct tv keybinding conflict with vi-mode`

---

### Staging

- **Never** use `git add -A` or `git add .`
- Stage files individually or by specific paths
- If a file should be gitignored (from Step 1) and user confirmed, add it to `.gitignore` instead of staging it

```bash
git add <specific files for this group>
```

---

### Commit

```bash
git commit -m "<confirmed message>"
```

If commit fails (hook, lint, etc.): report the error and help fix it. Do not use `--no-verify`.

---

### Push

After each commit:

```bash
git push
```

If no upstream set:
```bash
git push -u origin <current-branch>
```

If push fails (remote has new commits):
```bash
git pull --rebase
git push
```
If rebase has conflicts: help resolve them before pushing.

---

### After All Commits

- Report summary: N commits pushed, list of commit hashes (short) and messages
- If an active Obsidian project is set in `.claude/CLAUDE.md`: remind user to update project notes, or offer to run `/note` to mark completed tasks

---

## Context-Aware Behavior

**In a worktree** (`cwd` matches `~/worktrees/*/`):
- Suggest `/commit` proactively after completing a logical chunk of work
- Be slightly more aggressive about committing — worktrees are meant for iterative work

**In main repo:**
- Only commit when user explicitly invokes `/commit`
- Don't suggest committing unsolicited

## Rules

- Never `git add -A` or `git add .`
- Never `--no-verify` (don't skip hooks)
- Never `git push --force`
- Never commit secrets or credentials — refuse and gitignore them
- Always push after committing (this skill = stage + commit + push as one atomic action)
- If uncertain about a file's purpose: ask before staging or gitignoring
