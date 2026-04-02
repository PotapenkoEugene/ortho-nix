---
name: done
description: End-of-task wrap-up — update project notes, capture knowledge, commit and push all changes without confirmation prompts.
argument-hint: "[optional commit message override]"
allowed-tools: Bash(git *), Bash(find *), Bash(stat *), Bash(ls *), Bash(du *), Read, Edit, Glob, Grep
---

# Done Skill

End-of-task wrap-up that runs three phases in sequence:
1. **Note** — update the active project file with completions
2. **Knowledge** — capture any non-obvious insights to the knowledge base
3. **Commit** — stage, commit, and push all changes **without asking for confirmation**

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

## Rules

- Never `git add -A` or `git add .`
- Never `--no-verify`
- Never `git push --force`
- Never commit secrets — always gitignore them and warn
- Phase 1 and 2 failures are non-fatal — report the issue and continue to Phase 3
- Phase 3 is the only phase that must succeed; if git state is clean (nothing to commit), report that and finish
