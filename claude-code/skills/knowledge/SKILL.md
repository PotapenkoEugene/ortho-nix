---
name: knowledge
description: Save, build, search, and browse the Obsidian knowledge base. Captures insights from sessions as structured notes with knowledge-state tracking (seedling/budding/evergreen). Use for persisting research findings, building domain knowledge interactively, and creating project memory that survives beyond individual sessions.
---

# Knowledge Base Skill

Manage the Obsidian knowledge base at `~/Orthidian/knowledge/`. The knowledge base serves two purposes:
1. **Shared memory with the machine** — tracks what the user knows, is learning, and wants to learn, so future sessions start with context about the user's expertise level
2. **Project memory** — contextual knowledge (insights, references, gotchas) linked to projects for future sessions

## Knowledge States

Every knowledge note has a `status` field — the user's **relationship** to that knowledge:

| Status | Meaning | Icon | Default for |
|--------|---------|------|-------------|
| `seedling` | Want to know / unexplored / just a question | 🌱 | Captured interest, topic bookmarks |
| `budding` | Actively learning / partially understood | 🌿 | Auto-captured from sessions |
| `evergreen` | Well understood / confident / established | 🌳 | Deliberate `/knowledge build` confirmation |

Read status when calibrating explanations: don't over-explain evergreen topics; provide more scaffolding for seedlings.

## Directory Structure

```
~/Orthidian/knowledge/
  soloLTRs/              # existing project knowledge (unchanged)
  PROJECTNAME/           # per-project knowledge (created on demand, matches projects/ name)
    00-index.md          # MOC linking all files + project backlink
    NN-topic-slug.md     # numbered files (01-, 02-, ...)
  _technical/            # cross-project domain knowledge (underscore prefix)
    00-index.md
    topic-slug.md
  _biology/
    00-index.md
    topic-slug.md
  _bioinformatics/
    00-index.md
    topic-slug.md
  _personal/             # life knowledge, non-technical topics
    00-index.md
    topic-slug.md
```

## Knowledge Note Format

All new knowledge notes use this frontmatter:

```markdown
---
status: budding
domain: biology
created: 2026-03-28
updated: 2026-03-28
tags:
  - knowledge
  - domain/biology
projects:
  - "[[projects/soloLTRs]]"
---

# Topic Title

## Content

Main content here.

## Open Questions

- What is still unclear?
- What needs more investigation?

## Related
- [[knowledge/_biology/other-topic|Other Topic]]
- [[projects/soloLTRs]]
```

**Seedling notes** (minimal — just capture the question):
```markdown
---
status: seedling
domain: biology
created: 2026-03-28
updated: 2026-03-28
tags:
  - knowledge
  - domain/biology
---

# Topic Title

> [!question] Want to understand
> What is X? How does it relate to Y?

## Open Questions
- Main question that prompted this note
```

## Index File Format (MOC)

Every subdirectory has `00-index.md`:

```markdown
---
domain: biology
tags:
  - knowledge
  - MOC
---

# Biology Knowledge Base

Cross-project biology knowledge.
See also: [[knowledge/_technical/00-index|Technical]], [[knowledge/_bioinformatics/00-index|Bioinformatics]].

## Files

| File | Status | Contents |
|------|--------|----------|
| [[topic-slug\|Topic Name]] | 🌳 | One-line description |
| [[other-topic\|Other Topic]] | 🌿 | One-line description |
```

Project knowledge index links back to the project:
```markdown
# PROJECTNAME Knowledge Base

Knowledge collected for [[projects/PROJECTNAME]].

## Files
...
```

## Modes

### `/knowledge save [TARGET]`

Save insights from the current conversation to the knowledge base.

TARGET can be:
- A project name (e.g., `soloLTRs`, `ADAPTOGENE`) → saves to `knowledge/PROJECT/`
- A domain (e.g., `_biology`, `_technical`, `_bioinformatics`, `_personal`) → saves to `knowledge/_DOMAIN/`
- Omitted → ask the user which target makes sense

**Steps:**
1. Extract insights from the current conversation: facts, methods, comparisons, tool benchmarks, biological mechanisms, technical patterns — NOT tasks
2. Search existing files in the target directory for duplication:
   - `Glob("~/Orthidian/knowledge/TARGET/**/*.md")`
   - Read the `00-index.md` to see what already exists
   - Read any closely related files to check for overlap
3. If content overlaps with an existing file, append a new `##` section to that file (set `updated:` date in frontmatter)
4. If new content, create a new file:
   - Project knowledge: numbered `NN-topic-slug.md` (check current highest N, use N+1)
   - Domain knowledge: `topic-slug.md` (no numbering)
   - Set `status: budding`
5. Update `00-index.md` with the new row (Edit, not Write)
6. If linked to a project: add a backlink to the project file's `## Notes` section:
   ```
   - Knowledge: [[knowledge/PROJECT/topic-slug|Topic Name]]
   ```
7. Add `## Related` wikilinks pointing to related knowledge notes and project files

**Rules:**
- Append-only: never modify existing knowledge content, only add new sections
- Always re-read the target file before editing
- Use Edit tool for modifications, Write tool for new files
- Update the `updated:` frontmatter field when appending to an existing note

---

### `/knowledge build [TOPIC]`

Interactive knowledge-building session. Used when deliberately learning or documenting expertise — not just saving session residue.

**Steps:**
1. If TOPIC given, search `knowledge/` for existing notes on it:
   - `Grep(TOPIC, path="~/Orthidian/knowledge/")`
2. If found: read the current note, summarize what's captured, then ask:
   - "Current status: [status]. What has changed in your understanding?"
   - Walk through open questions, fill gaps, update content
3. If not found: create a new note collaboratively:
   - Ask: which domain or project does this belong to?
   - Ask: what do you already know? what questions do you have?
   - Structure the note from the discussion
4. At end of session, confirm the `status` based on discussion:
   - `seedling` — just captured the topic, many open questions
   - `budding` — partially understood, actively learning
   - `evergreen` — confident, well-established understanding
5. Update `00-index.md` with entry or updated status icon

Use the `/obsidian-markdown` skill conventions for note formatting (callouts, wikilinks, etc.).

---

### `/knowledge search QUERY`

Search the knowledge base for QUERY.

**Steps:**
1. Use the `mcpvault` MCP server's `search_notes` tool with the query
2. If mcpvault unavailable, fall back to: `Grep(QUERY, path="~/Orthidian/knowledge/", output_mode="content")`
3. Display results with: file path, status (from frontmatter), domain, linked projects, matching excerpt
4. Offer to:
   - Read the full note
   - Update the status (e.g., promote seedling → budding)
   - Find related notes via `## Related` links

---

### `/knowledge` (no args) — Browse

1. List all subdirectories in `~/Orthidian/knowledge/`
2. For each, show: name, file count, status distribution (🌱/🌿/🌳 counts)
3. Highlight seedling notes that haven't been updated recently (potential learning gaps)
4. Let user select a directory to explore its index

---

## Cross-linking Rules

- **Knowledge → project**: always include `[[projects/PROJECTNAME]]` in `## Related` and in `projects:` frontmatter
- **Project → knowledge**: always add `- Knowledge: [[knowledge/PATH|Title]]` to the project file's `## Notes` section
- **Knowledge → knowledge**: link related notes across domains via `## Related`; use full paths for cross-directory links: `[[knowledge/_biology/topic]]`; use short links within same directory: `[[topic-slug]]`
- Never create orphan knowledge notes — every note must be reachable from its `00-index.md`

## Duplication Prevention

Before creating a new file, always:
1. Read `00-index.md` to see what's already captured
2. Glob all files in the target directory
3. Read closely-related files by title similarity
4. Check semantically — "fast alignment benchmarks" and "alignment speed comparison" are duplicates

If content overlaps >50%, append to the existing file rather than creating a new one.

## File Naming

- Project knowledge: `NN-topic-slug.md` where NN is zero-padded next number (01, 02, ... 09, 10, ...)
- Domain knowledge: `topic-slug.md` — lowercase, hyphens, no numbers
- Index: always `00-index.md`
- Slugs: lowercase, hyphens only, no spaces or special characters

## Important Rules

- Never delete or overwrite existing knowledge content — append-only
- Always re-read a file before editing it (Edit tool)
- Use Write tool only for creating new files
- Never modify `soloLTRs/` files — that knowledge was manually curated
- Daily notes (`~/Orthidian/daily/`) are read-only — never touch them
- Project files (`~/Orthidian/projects/`) may only have `## Notes` or `## Related` backlinks appended — never modify task structure
