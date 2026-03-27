# Global Claude Code Instructions

These rules apply to ALL projects and sessions. Project-level CLAUDE.md files add on top of these.

## Workflow

- **Always plan first.** Use EnterPlanMode before implementing, even for small tasks. Explore the codebase, design the approach, get approval, then execute.
- **Ask questions aggressively.** My prompts are brief — don't guess intent. Ask clarifying questions upfront before starting AND mid-task when encountering ambiguity or decision points.
- **Task lists for 3+ steps.** Always create a task list (TaskCreate) when work involves 3 or more steps. Update status as you go.
- **When I approve results** with positive words (amazing, awesome, great, perfect — without "but" or follow-up corrections), that means the task is done. Mark it completed.

## Package Management

- **Permanent tool** → add to `modules/packages.nix` and apply via `/hm-switch`. Nix config is the source of truth for all installed software.
- **Temporary/one-off tool** → `nix shell nixpkgs#<pkg>` — no config change, no trace left.
- **Never suggest** `pip install`, `npm install -g`, `cargo install`, or `brew install` without a Nix wrapper. If no nixpkgs package exists, propose a custom derivation or use `nix shell`.
- **Quick comparison for new tools.** Briefly compare 2-3 alternatives (features, activity, nixpkgs availability), recommend one, move on.

## Communication

- **Always English.** All communication in English regardless of context.
- **Concise and technical.** Prefer precise language, avoid filler. Cite specific file paths, line numbers, version numbers. Bullet points over paragraphs.
- **No emoji** unless I explicitly ask.

## Error Handling

- **Diagnose and fix autonomously.** When hitting build failures, test failures, or unexpected output — investigate root cause and attempt a fix. Only ask me if stuck after 2-3 attempts.

## Data Safety

- **Never modify raw data.** Treat anything in `data/`, `raw/`, or input directories as read-only. Always create new output files rather than overwriting source data.

## Git

- **Use `/commit` for all commits.** Never commit without the skill — it handles staging, gitignore hygiene, commit message, and push in one flow.
- **Use `/worktree` for parallel work.** Create worktrees for large features; merge back with squash when done.
- **In worktrees:** suggest `/commit` proactively after completing a logical chunk of work.
- **In main:** only commit when user explicitly asks.
- **Never force push.** Never rewrite published history.
- **Repo hygiene:** before staging, check for files that should be gitignored (large files >1MB, secrets, build artifacts, tool caches). Propose `.gitignore` additions. When unsure, ask.

## Task Completion

- After finishing a task or logical chunk of work:
  - Ask if user wants to commit the changes (suggest `/commit`)
  - Update the active project file via `/note` (mark subtasks done, add completion notes)
- In worktrees: suggest both proactively after each completed chunk.
- In main: only suggest when explicitly relevant (don't nag after every small edit).

## Academic Writing

- **Concise and technical.** When editing manuscripts or scientific text, use precise scientific language. Avoid hedging, filler, and unnecessary qualifiers. Cite specific data, figures, and results.

## Browser Automation (playwright-cli)

- **Use `playwright-cli` for any task requiring visual or interactive web info**: inspecting local apps, scraping page content, checking UI state, taking screenshots, filling forms, clicking through flows.
- **Standard workflow:**
  1. `playwright-cli open <url>` — launch headless browser and navigate
  2. `playwright-cli snapshot` — get accessibility tree (structure, text, refs)
  3. `playwright-cli screenshot` — capture visual state (saved to `.playwright-cli/`)
  4. `playwright-cli goto / click / fill / type` — interact with elements by ref
  5. `playwright-cli close` — always close when done
- **Visual QA for HTML output.** When building anything that produces `.html` (websites, Shiny apps, dashboards, reports) — always open the result with `playwright-cli`, screenshot it, and assess the visual output. Improve layout, spacing, typography, color, and responsiveness based on UI/UX best practices before considering the task done.
- **Session persistence:** use `-s=<name>` flag to keep a named session open across commands (useful for multi-step flows).
- **Local Shiny apps:** pair with `options(shiny.autoreload = TRUE)` — edit code, then snapshot/screenshot to verify changes without restarting.
- **Run `playwright-cli install` once per new working directory** to initialize the workspace config and download browsers if missing.
- **Browsers stored at:** `~/.cache/ms-playwright/chromium-1212/`

## Home Manager

- **Always use `/hm-switch`** for any config change — never raw `home-manager switch`. The skill runs alejandra → build → switch → git diff.
- Config lives in `~/.config/home-manager/`. Modules in `modules/`, scripts in `scripts/`, Claude Code config in `claude-code/`.
- New files must be `git add`-ed before `home-manager build` (flake only sees git-tracked files).
- **Never edit Nix store symlinks.** Files under `/nix/store/` are immutable. If a target file is a symlink into the store (e.g. `~/.claude/CLAUDE.md` → `/nix/store/…`), find the source in `~/.config/home-manager/` and edit that instead.
- If build fails, fix and retry — never skip the build test step.

## Shiny Development

- **Use `/shiny-bslib` skill** when building or modifying Shiny UI — covers bslib layouts, cards, value boxes, sidebars, theming.
- **Visual iteration loop:** start app with `options(shiny.autoreload = TRUE)`, then use playwright-cli to screenshot after each edit.
- **Theming:** use `/shiny-bslib-theming` skill for bs_theme(), Bootswatch, custom Sass, dark mode.

## Email & Calendar

- **Use `/mail` skill** for inbox triage, email composition, and digest generation.
- Accounts: `selfisheugenes` (personal + GCP) and `potapgene` — both via `gws` CLI with isolated config dirs.
- Switch accounts via `GOOGLE_WORKSPACE_CLI_CONFIG_DIR=~/.config/gws/accounts/<account>`.
- Calendar: `gws calendar +agenda --today` for events; Google Tasks synced to `~/Orthidian/personal/tasks.md`.

## Presentations

- **Use `/presenterm` skill** for any terminal-based presentation from markdown.
- Supports: themes, code execution, mermaid/d2 diagrams, LaTeX formulas, PDF/HTML export.
- Presentation files go in the project directory as `*.md` with presenterm frontmatter.

## Obsidian Integration

- Note system at `~/Orthidian/`. Project files in `projects/` and `personal/` are append-only archives.
- **Use `/note PROJECTNAME` at session start** when working on a tracked project.
- After `/note`, autonomously manage the project file:
  - Mark subtasks `[x]` when completed, add `- Done YYYY-MM-DD: description` notes
  - **Always ask before marking top-level objectives `[x]`** — user decides when an objective is done
  - Create top-level objectives only when user suggests it
  - Add new subtasks discovered during work
  - Never delete tasks
- **Daily notes (`~/Orthidian/daily/`) are read-only views.** Never modify them.
