---
name: done
description: End-of-task wrap-up — note → knowledge → commit+push (local repo only) → understand-graph update (if graph exists).
argument-hint: "[optional commit message override]"
allowed-tools: Bash(git *), Bash(find *), Bash(stat *), Bash(ls *), Bash(du *), Bash(jq *), Read, Edit, Glob, Grep
---

# Done Skill

End-of-task wrap-up that runs up to four phases in sequence:
1. **Note** — update the active project file with completions
2. **Knowledge** — capture any non-obvious insights to the knowledge base
3. **Commit** — stage, commit, and push all changes **without asking for confirmation** (skipped if CWD is not inside a git repo)
4. **Understand Graph** — incrementally update the knowledge graph (skipped if no graph exists in CWD)

## Usage

- `/done` — full auto wrap-up
- `/done "message"` — treat all changes as one group with this commit message

---

## Phase 1: Note Update

Read the active project from `.claude/CLAUDE.md` under `## Active Obsidian Project`.

**If no active project is set:** skip this phase silently.

**If set:**
1. Read the project file at the listed path
2. Identify subtasks completed during this session based on conversation context
3. For each completed subtask: mark it `[x]` and add a child line:
   ```markdown
   - [x] Subtask text
       - Done YYYY-MM-DD: brief description of what was done
   ```
4. Add any new subtasks discovered during the work under the relevant objective
5. **Do not** mark top-level objectives `[x]` — only subtasks
6. **Do not** delete or rewrite existing content
7. Always re-read the file immediately before editing (use Read, then Edit)

Report: "Updated [ProjectName]: marked N subtask(s) done, added M new subtask(s)"

---

## Phase 2: Knowledge Capture

Review the current conversation for insights worth persisting:
- Technical findings, gotchas, tool behaviors, configuration patterns
- Comparisons, benchmarks, design decisions with rationale
- Non-obvious facts discovered during debugging or research

**Skip this phase if** nothing was learned beyond what's already in the code (e.g., pure mechanical edits with no research).

**If insights exist:**
1. Search for duplicates first:
   - Use mcpvault `search_notes` tool if available, or Grep `~/Orthidian/knowledge/`
2. Determine target: project knowledge (`knowledge/PROJECTNAME/`) or domain (`knowledge/_technical/`, `_biology/`, etc.)
3. Create or append a knowledge note following the format in `/knowledge` skill conventions:
   - Frontmatter: `status: budding`, `domain`, `created`, `updated`, `tags`, `projects`
   - Include `## Open Questions` if anything is still unclear
4. If target directory lacks `00-index.md`: create it
5. Add a backlink in the project file `## Notes` section:
   ```markdown
   - Knowledge: [[knowledge/PATH|Title]]
   ```

Report: "Saved knowledge: [N note(s) created/updated]" or "No new knowledge to capture"

---

## Phase 3: Commit + Push (No Confirmation)

### CWD Git Guard

First, check whether the current working directory is inside a git repo:

```bash
git -C "$PWD" rev-parse --is-inside-work-tree 2>/dev/null
```

- **Exit code != 0** → print "Phase 3 skipped: not inside a git repo." and jump to Phase 4. Do not `cd` anywhere else.
- **Exit code == 0** → proceed below.

### Gitignore Hygiene

```bash
git status --porcelain
git ls-files --others --exclude-standard
```

Scan untracked files for things that should be ignored:

| Category | Patterns |
|----------|----------|
| Large files | Any file >1MB |
| Nix build | `result`, `result-*` |
| Build artifacts | `dist/`, `build/`, `*.o`, `*.so` |
| Editor/IDE | `.idea/`, `.vscode/`, `*.swp`, `.DS_Store` |
| Python | `__pycache__/`, `*.pyc`, `.pytest_cache/`, `*.egg-info/` |
| R | `.Rhistory`, `.RData`, `.Rproj.user/` |
| Models/media | `*.gguf`, `*.wav`, `*.mp3`, `*.mp4` |
| **Secrets** | `.env`, `*secret*`, `*credential*`, `*.pem`, `*.key`, `*token*` |
| Tool caches | `.playwright-cli/`, `.cache/`, `*.log` |
| Data files | `*.csv >1MB`, `*.tsv >1MB`, `*.parquet`, `*.sqlite` |

- **Secrets**: warn loudly, do NOT commit — add to `.gitignore` and stop
- **Everything else**: auto-add to `.gitignore` without asking, stage `.gitignore` as part of the commit

### Understand What Changed

```bash
git status
git diff --stat HEAD
git diff HEAD
```

Use conversation context (what was built, fixed, configured) + the diff to understand the intent behind each changed file.

**Group changes into logical commits:**
- A logical group = files belonging to the same feature, fix, or concern
- Separate groups when changes are unrelated (e.g., "add R packages" vs "fix gnome keybinding")

### Execute All Groups — No Confirmation

**Do not present groups to the user. Do not ask for approval. Execute immediately.**

For each group in order:
1. Stage the specific files for that group:
   ```bash
   git add <specific files>
   ```
2. Generate a Conventional Commits message:
   ```
   <type>(<scope>): <short summary>
   ```
   Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `style`
3. Commit:
   ```bash
   git commit -m "<message>"
   ```
4. Push:
   ```bash
   git push
   ```
   If no upstream: `git push -u origin <branch>`
   If push fails due to remote changes: `git pull --rebase && git push`

**If argument provided** (`/done "message"`): treat all changes as one group with that message.

**If commit fails** (hook, lint error): report the error and fix it. Do not use `--no-verify`.

### Report

After all commits:
```
Done: 2 commits pushed
  abc1234 feat(claude-code): add /done skill
  def5678 chore(nix): add done skill symlink
```

---

## Phase 4: Understand Graph Update

Runs after push so the graph diffs against the committed HEAD.

### Pre-conditions (check in order — skip silently on any miss)

1. CWD is inside a git repo (`git -C "$PWD" rev-parse --is-inside-work-tree 2>/dev/null` succeeds).
2. `.understand-anything/knowledge-graph.json` exists in CWD — if not, skip silently (no graph means user hasn't opted in to this project).
3. `.understand-anything/meta.json` exists in CWD with a readable `gitCommitHash` field.

### Short-circuit: graph already up to date

```bash
CURRENT_HASH=$(git rev-parse HEAD)
LAST_HASH=$(jq -r .gitCommitHash .understand-anything/meta.json)
```

If `CURRENT_HASH == LAST_HASH` → report "Phase 4: graph already up to date." and finish. Zero tokens spent.

### Incremental update

Locate and read the plugin's auto-update prompt:

```bash
HOOK=$(find ~/.claude/plugins/cache/understand-anything -name auto-update-prompt.md 2>/dev/null | head -1)
```

Read `$HOOK` with the Read tool and follow its Phase 0 → Phase 3 instructions verbatim, anchoring `$PROJECT_ROOT` to the current working directory (`$PWD`). Do **not** inline or paraphrase the logic — execute the prompt file as-is so future plugin version upgrades flow through automatically.

If `$HOOK` is empty (plugin not installed), print "Phase 4 skipped: understand-anything plugin not found." and finish.

Phase 4 is **non-fatal** — if the update errors mid-run, report the error in one line and finish. The existing graph stays intact.

---

## Rules

- Never `git add -A` or `git add .`
- Never `--no-verify`
- Never `git push --force`
- Never commit secrets — always gitignore them and warn
- Phase 3 operates **only** on the git repo whose work tree contains `$PWD`. Never `cd` elsewhere for git commands. `~/Orthidian/*` edits from Phase 2 stay uncommitted on disk — they are handled by Orthidian's own backup timer.
- Phase 3 skips silently when CWD is not inside a git repo.
- Phase 4 skips silently when CWD has no `.understand-anything/knowledge-graph.json` — graph maintenance is opt-in per project.
- Phase 1, 2, and 4 failures are non-fatal — report the issue and continue. Phase 3 is the only phase that must succeed; if git state is clean (nothing to commit), report that and finish.
