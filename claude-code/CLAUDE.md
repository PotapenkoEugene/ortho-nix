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

## MANDATORY: After Every Feature or Logical Chunk

**After completing any meaningful implementation** (a new feature, a fix, a config change, a skill, a script — anything that "works" as a unit), always ask:

> "Finished [X]. Run `/done`? (y/n)"

Wait for yes or no. One line, no elaboration. If yes, run `/done`. If no, continue.

**What counts as a trigger:**
- A feature or subtask reaches a working state
- A bug is fixed and verified
- A config change is applied and tested (e.g., after `/hm-switch`)
- A skill or script is written and ready
- The user says something like "ok", "done", "looks good", "great", "perfect"

**What does NOT trigger it:**
- Mid-implementation (still in the middle of a multi-step task)
- Pure research/exploration with no code changes
- Small clarifications or follow-up questions

This is a default reflex — the user should never have to remember to ask for it.

## Git

- **Use `/done` for wrap-up** — notes + knowledge + commit + push, no confirmation prompts.
- **Use `/commit` when you need manual control** over grouping or want to review before pushing.
- **Use `/worktree` for parallel work.** Create worktrees for large features; merge back with squash when done.
- **Never force push.** Never rewrite published history.
- **Repo hygiene:** `/done` and `/commit` both scan for gitignore candidates before staging.

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

## R Analysis

- **Use `/tidy-r` skill** when writing R scripts — covers tidyverse style, ggplot2 patterns, data.table, project structure.
- Use `Rscript` via nix rWrapper (already in `modules/packages.nix`). Never use system R.
- Prefer tidyverse idioms; data.table for large datasets (>1M rows).
- All plots: ggplot2 with consistent theming. Publication-ready by default.
- File paths: always `here::here()`, never `setwd()` or relative paths.

## Bioinformatics & Scientific Analysis

- **Scientific skills installed** from [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills): `scanpy`, `biopython`, `pydeseq2`, `deeptools`, `scikit-bio`, `anndata`, `statistical-analysis`, `statsmodels`, `scikit-learn`, `scikit-survival`, `pymc`, `shap`, plus database skills (gene, ensembl, clinvar, gnomad, gwas, pubmed, kegg).
- Use the relevant skill when the task matches: DEG analysis → `pydeseq2`, single-cell → `scanpy`, statistics → `statistical-analysis`, survival → `scikit-survival`, etc.
- **New analysis type not covered by installed skills?** Browse the full repo (177 skills, MIT) for the right skill — microbiology, proteomics, metabolomics, clinical trials, cheminformatics, and more. Fetch the SKILL.md directly from raw.githubusercontent.com as a reference when needed.
- CLI tools available via nix: samtools, bcftools, bedtools, fastqc, bowtie2, minimap2, seqkit, macs2, multiqc, igv, kent.
- R Bioconductor packages (DESeq2, GenomicRanges, etc.) via micromamba, not nix.
- Both R and Python are valid — use whichever fits the task.

## Document Grounding (NotebookLM)

NotebookLM provides source-grounded AI — answers come strictly from uploaded documents with citations. Two modes: always-on collection during exploration, and direct investigation on request.

### Always-On: Source Collection During Exploration

During any exploration, planning, or research work — when you encounter valuable documentation URLs, papers, tutorials, or references — **automatically** add them to NotebookLM without asking:

1. **Categorize** into `{Project}_{topic}` notebook (e.g., `ADAPTOGENE_gwas`, `Desktop_nix`, `soloLTRs_transposable-elements`)
2. **Auto-create** notebook if new topic (`notebooklm create "{Project}_{topic}"`), or add to existing (ID from project file `## Notes`)
3. **Add task** to task list: "Extract knowledge from {notebook} → knowledge base"
4. **After exploration**: query notebook for key concepts, save grounded notes to `~/Orthidian/knowledge/` — check mcpvault for duplicates first
5. **At >5 sources**: mention to user once — "want a Russian podcast for {notebook}?"
6. **Track association** in project file `## Notes`: `- NotebookLM: {Project}_{topic} ({notebook_id})`

**Never ask permission to create notebooks or add sources. Do ask before generating podcasts.**

### Direct Investigation

When user asks to investigate a topic: use `/notebook investigate <topic>` — full pipeline from research to knowledge base, with podcast offer at the end.

### Naming Convention

`{Project}_{topic}` always:
- `Desktop_nix`, `Desktop_nvim`, `Desktop_tmux`, `Desktop_claude-code`
- `ADAPTOGENE_gwas`, `ADAPTOGENE_populationGenomics`, `ADAPTOGENE_pipeline`
- `soloLTRs_transposable-elements`, `soloLTRs_bioinformatics-tools`

### Conventions

- Knowledge notes: English, `status: budding`, frontmatter `source-type: notebooklm-grounded`, `notebooklm-notebook: <id>`
- Podcasts: Russian (`--language ru`), `~/podcasts/{Project}_{topic}_ru.mp3`
- Auth: `notebooklm login` (browser OAuth, one-time). Credentials at `~/.notebooklm/`.
- Full CLI reference: `/notebooklm` skill

## Transcript Processing

- **Use `/process-transcript`** for new whisper recordings in `~/Orthidian/transcripts/`.
- Prefer polished files (`*-polished.txt`) over raw or clean versions.
- Output goes to `~/Orthidian/processed-transcripts/`.

## Presentations

- **Use `/presenterm` skill** for any terminal-based presentation from markdown.
- Supports: themes, code execution, mermaid/d2 diagrams, LaTeX formulas, PDF/HTML export.
- Presentation files go in the project directory as `*.md` with presenterm frontmatter.

## Obsidian Integration

- Note system at `~/Orthidian/`. Project files in `projects/` and `personal/` are append-only archives.
- `/note` runs automatically at session start via the CLI alias — no need to invoke it manually.
- **`/done` is the wrap-up trigger** (see MANDATORY section above) — marks subtasks, captures knowledge, commits, pushes.
- Between start and wrap-up, autonomously manage the project file as work progresses:
  - Mark subtasks `[x]` when completed, add `- Done YYYY-MM-DD: description` notes
  - **Always ask before marking top-level objectives `[x]`** — user decides when an objective is done
  - Create top-level objectives only when user suggests it
  - Add new subtasks discovered during work
  - Never delete tasks
- **Daily notes (`~/Orthidian/daily/`) are read-only views.** Never modify them.

### Knowledge Base

- Knowledge notes live in `~/Orthidian/knowledge/`. Two subdirectory types:
  - **Project knowledge** (`knowledge/soloLTRs/`, `knowledge/ADAPTOGENE/`): deep-dive notes for a specific project, numbered files + `00-index.md`
  - **Domain knowledge** (`knowledge/_technical/`, `knowledge/_biology/`, `knowledge/_bioinformatics/`, `knowledge/_personal/`): cross-project reference material, underscore-prefixed dirs
- **Knowledge states** — every note has a `status` field, read it to calibrate explanations:
  - `seedling` 🌱 — want to know / unexplored / just a question. Give foundational context.
  - `budding` 🌿 — actively learning / partially understood. Build on what's there.
  - `evergreen` 🌳 — well understood / confident. Skip basics, go deep.
- **Auto-capture** — when research, debugging, or analysis yields significant insights, facts, or methods: these are saved automatically by `/done` (Phase 2). Set status to `budding`. This is how shared memory grows.
- **Project memory** — when knowledge is linked to a project, add a backlink in the project file's `## Notes` section: `- Knowledge: [[knowledge/PATH|Title]]`
- **Before creating knowledge**: search existing notes to avoid duplication (`/knowledge search` or mcpvault `search_notes`).
- **Use `/knowledge build`** for deliberate, interactive learning sessions — structuring what you know, filling gaps, confirming status.
- All knowledge notes use frontmatter: `status`, `domain`, `created`, `updated`, `tags`, `projects`.
- Cross-link everything: knowledge notes link to projects and to each other via `[[wikilinks]]`.
