# note

Add insights from conversation to Obsidian project files.

## Instructions

You are helping to capture valuable insights from the current conversation into the user's Obsidian project note system.

### Task Structure Rules

**CRITICAL CONSTRAINTS:**
- **NEVER create new top-level objectives** - they already exist in project files
- **ONLY add subtasks** to existing objectives
- **ONLY add comments** to existing objectives or subtasks
- **NO redundancy** - check existing subtasks before adding
- **Project files are archives** - never delete anything, only add

### Workflow

1. **Analyze the conversation** to extract:
   - Actionable subtasks (tasks that need to be done)
   - Technical insights/notes (comments explaining context)
   - Decisions made
   - Problems discovered and solutions

2. **Get project context:**
   ```bash
   # List available projects
   ls ~/Orthidian/projects/*.md | xargs -n1 basename -s .md
   ```

3. **Ask the user which project** to add notes to (use AskUserQuestion):
   - Show available projects as options
   - Ask for project selection

4. **Read the selected project file:**
   ```bash
   cat ~/Orthidian/projects/<PROJECT_NAME>.md
   ```

5. **Ask which objective** to add to (use AskUserQuestion):
   - Parse the "## Objectives" section
   - Show top-level tasks (lines starting with `- [ ]` or `- [x]` at base indent)
   - Let user select which objective is relevant

6. **Check for redundancy:**
   - Read all existing subtasks under the selected objective
   - Compare extracted insights with existing subtasks
   - **Only include new, non-duplicate items**
   - Use semantic matching (not just exact string match)

7. **Format additions properly:**

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

8. **Add to project file:**
   - Find the exact line of the selected objective
   - Insert new subtasks/comments at the appropriate indent level
   - Maintain existing structure
   - Use Edit tool to add new items

9. **Verify and report:**
   - Show what was added
   - Confirm the location (project name, objective title)

### Example Structure

```markdown
## Objectives
- [ ] Update pipeline
    - [x] Configure access to hubnerlab git
    - [x] Fix topr version
    - [ ] Add GAPIT association analysis  ← CAN ADD SUBTASKS HERE
        - Before that should be add phenotype processing ← CAN ADD COMMENTS HERE
    - [ ] Add Haplotype analysis  ← CAN ADD SUBTASKS HERE
```

**Valid additions:**
- `    - [ ] Implement BLINK algorithm` (subtask under "Update pipeline")
- `        - Consider using linear mixed models` (comment under "Add GAPIT")

**Invalid additions:**
- `- [ ] New top-level objective` (NOT ALLOWED)
- Duplicate of existing subtask (NOT ALLOWED)

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

After successfully adding to project file:
1. Show summary of what was added
2. Indicate which project and objective
3. Confirm no duplicates were created

## Example Usage

**User:** This GAPIT analysis needs better SNP filtering

**Claude:**
1. Lists projects: ADAPTOGENE, CutNrun, GenomeSize...
2. User selects: "ADAPTOGENE"
3. Reads project file, shows objectives
4. User selects: "Update pipeline" → "Add GAPIT association analysis"
5. Checks existing subtasks: "Before that should be add phenotype processing"
6. Extracts new insight: "Improve SNP filtering in BLINK algorithm"
7. Verifies not duplicate
8. Adds: `        - [ ] Improve SNP filtering in BLINK algorithm`
9. Reports: "Added subtask to ADAPTOGENE → Update pipeline → Add GAPIT association analysis"

## Important

- Always use Read tool to check current state
- Always use Edit tool to modify (never Write)
- Preserve exact indentation (4 spaces per level)
- Maintain checkbox format: `- [ ]` for undone, `- [x]` for done
- Never modify existing tasks unless explicitly asked
