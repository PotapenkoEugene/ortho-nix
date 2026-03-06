# note

Manage Obsidian project tasks — add insights, track progress, mark completions.

## Instructions

You help capture insights and track task progress in the user's Obsidian project note system.

### Modes

**Quick-start mode**: `/note PROJECTNAME`
1. Validate project exists in `~/Orthidian/projects/` or `~/Orthidian/personal/`
2. Read project file, display current objectives
3. Suggest the first undone task: "Next: [objective] > [subtask]"
4. Write project association to working directory's `.claude/CLAUDE.md`:
   ```markdown
   ## Active Obsidian Project
   - Project: PROJECTNAME
   - File: ~/Orthidian/projects/PROJECTNAME.md
   ```

**Interactive mode**: `/note` (no args)
1. List available projects from both `projects/` and `personal/`
2. Ask user to select one (use AskUserQuestion)
3. Proceed as quick-start mode

### Task Structure Rules

**CRITICAL CONSTRAINTS:**
- **Top-level objectives**: only create when the user suggests it (never autonomously)
- **ONLY add subtasks** to existing objectives
- **ONLY add comments** to existing objectives or subtasks
- **NO redundancy** — check existing subtasks before adding
- **Project files are archives** — never delete anything, only add

### Autonomous Task Tracking

After `/note` sets the active project for a session, autonomously manage the project file as you work:

**Marking subtasks complete:**
- When you complete a subtask, mark it `[x]` in the project file
- Add a completion note as a child line (4-space indent):
  ```markdown
  - [x] Implement feature X
      - Done 2026-03-05: Added X with Y approach, tested with Z
  ```
- Mark subtasks done autonomously when confident the user would agree

**Marking top-level objectives complete:**
- **ALWAYS ask the user** before marking a top-level objective `[x]`
- Subtasks being done does NOT mean the objective is done — the user decides
- The daily note dashboard tracks the objective's own `[x]` marker, not subtask state

**Adding new subtasks:**
- When you discover work needed during implementation, add subtasks under existing objectives
- Use Edit tool (never Write) — always re-read the file before modifying

**Rules:**
- Never delete tasks
- Never modify existing task text (only markers and adding children)
- Always re-read the project file before each edit

### Insight Capture Workflow

When adding insights from conversation:

1. **Analyze the conversation** to extract:
   - Actionable subtasks (tasks that need to be done)
   - Technical insights/notes (comments explaining context)
   - Decisions made
   - Problems discovered and solutions

2. **Read the project file:**
   ```bash
   cat ~/Orthidian/projects/<PROJECT_NAME>.md
   ```

3. **Ask which objective** to add to (use AskUserQuestion):
   - Parse the `## Objectives` section
   - Show top-level tasks as options
   - Let user select which objective is relevant

4. **Check for redundancy:**
   - Read all existing subtasks under the selected objective
   - Compare extracted insights with existing subtasks
   - **Only include new, non-duplicate items**
   - Use semantic matching (not just exact string match)

5. **Format additions properly:**

   **For subtasks:**
   ```markdown
   - [ ] Top-level objective
       - [x] Existing subtask
       - [ ] NEW SUBTASK HERE (proper indent: 4 spaces)
   ```

   **For comments/notes:**
   ```markdown
   - [ ] Top-level objective
       - [ ] Existing subtask
           - Technical note or insight (8 spaces for nested comment)
       - General note about objective (4 spaces for direct comment)
   ```

   **For completion notes:**
   ```markdown
   - [x] Completed subtask
       - Done 2026-03-05: description of what was done
   ```

6. **Add to project file:**
   - Find the exact line of the selected objective
   - Insert new subtasks/comments at the appropriate indent level
   - Maintain existing structure
   - Use Edit tool to add new items

7. **Verify and report:**
   - Show what was added
   - Confirm the location (project name, objective title)

### Redundancy Detection

When checking if a subtask already exists:
- Strip formatting (checkboxes, whitespace)
- Compare semantic meaning, not exact strings
- Variations of the same task count as duplicates

**Examples of duplicates:**
- "Add error handling" = "Implement error handling" = "Error handling needed"
- "Fix bug in login" = "Resolve login bug"

### Notes Format Guidelines

**Subtasks** (actionable items):
```markdown
- [ ] Clear action verb + specific outcome
- [ ] Configure X to do Y
- [ ] Implement feature Z
```

**Comments** (explanatory notes):
```markdown
- Technical context or explanation
- Reason for design decision
- Problem description or consideration
```

### Output

After successfully modifying a project file:
1. Show summary of what was added/changed
2. Indicate which project and objective
3. Confirm no duplicates were created

## Example Usage

**Quick-start:** `/note Desktop`
1. Reads `~/Orthidian/projects/Desktop.md`
2. Shows objectives: "Claude Code Skills", "Obsidian Automation"
3. Suggests: "Next: Claude Code Skills > /test skill - detect framework, run relevant tests"
4. Writes project association to `.claude/CLAUDE.md`

**Insight capture:** `/note`
1. Lists projects: ADAPTOGENE, BOB, Conferences, CutNrun, Desktop, ...
2. User selects: "ADAPTOGENE"
3. Reads project file, shows objectives
4. User selects: "Update pipeline" > "Add GAPIT association analysis"
5. Checks existing subtasks
6. Adds: `        - [ ] Improve SNP filtering in BLINK algorithm`
7. Reports: "Added subtask to ADAPTOGENE > Update pipeline > Add GAPIT"

**Task completion during session:**
1. `/note Desktop` at session start
2. Work on `/test skill`... complete it
3. Claude marks `[x]` in Desktop.md and adds completion note

## Important

- Always use Read tool to check current state before modifying
- Always use Edit tool to modify (never Write)
- Preserve exact indentation (4 spaces per level)
- Maintain checkbox format: `- [ ]` for undone, `- [x]` for done
- Never modify existing task text unless explicitly asked
- Completion notes format: `- Done YYYY-MM-DD: description`
