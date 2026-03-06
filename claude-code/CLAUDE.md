# Global Claude Code Instructions

These rules apply to ALL projects and sessions. Project-level CLAUDE.md files add on top of these.

## Workflow

- **Always plan first.** Use EnterPlanMode before implementing, even for small tasks. Explore the codebase, design the approach, get approval, then execute.
- **Ask questions aggressively.** My prompts are brief — don't guess intent. Ask clarifying questions upfront before starting AND mid-task when encountering ambiguity or decision points.
- **Task lists for 3+ steps.** Always create a task list (TaskCreate) when work involves 3 or more steps. Update status as you go.
- **When I approve results** with positive words (amazing, awesome, great, perfect — without "but" or follow-up corrections), that means the task is done. Mark it completed.

## Tool & Package Research

- **Nix-first.** Always check nixpkgs availability before suggesting pip, npm, cargo, or manual install. I use Nix Home Manager for all system-level tooling.
- **Quick comparison for new tools.** When I suggest a tool or you want to recommend one, briefly compare 2-3 alternatives (features, activity, nixpkgs availability), recommend one, and move on. Don't over-research unless I ask for depth.

## Communication

- **Always English.** All communication in English regardless of context.
- **Concise and technical.** Prefer precise language, avoid filler. Cite specific file paths, line numbers, version numbers. Bullet points over paragraphs.
- **No emoji** unless I explicitly ask.

## Error Handling

- **Diagnose and fix autonomously.** When hitting build failures, test failures, or unexpected output — investigate root cause and attempt a fix. Only ask me if stuck after 2-3 attempts.

## Data Safety

- **Never modify raw data.** Treat anything in `data/`, `raw/`, or input directories as read-only. Always create new output files rather than overwriting source data.

## Git

- **I handle git myself.** Never auto-commit, never push. Don't create commits unless I explicitly say "commit this" or similar. Don't suggest committing after every change.

## Academic Writing

- **Concise and technical.** When editing manuscripts or scientific text, use precise scientific language. Avoid hedging, filler, and unnecessary qualifiers. Cite specific data, figures, and results.

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
