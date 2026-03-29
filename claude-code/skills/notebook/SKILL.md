---
name: notebook
description: Pre-session documentation digest and research synthesis via Google NotebookLM. Grounds AI answers in uploaded sources with citations. Use before coding with unfamiliar tools or synthesizing research papers.
argument-hint: "[prep|research|ask] [topic/question]"
---

# notebook

NotebookLM workflow skill — source-grounded document processing for coding and research sessions.

Uses the `notebooklm` CLI (`notebooklm-py` package). Consult the `/notebooklm` skill for the full CLI reference (notebook management, source upload, artifact generation).

## Authentication

One-time setup:
```bash
notebooklm login
```
Opens a browser for Google OAuth. Credentials stored at `~/.notebooklm/`. Re-run if auth expires.

## Modes

### `/notebook prep <topic>`

Pre-session documentation digest — feeds docs into NotebookLM and extracts a grounded summary as coding context.

**Workflow:**
1. Ask user for documentation sources (URLs, PDFs, YouTube tutorials)
2. Find or create a notebook for the topic:
   ```bash
   notebooklm list --json  # look for existing notebook
   notebooklm create "<topic>" --json  # or create new
   ```
3. Add sources (run in parallel when multiple):
   ```bash
   notebooklm source add "<url>" -n <notebook_id>
   ```
4. Wait for processing:
   ```bash
   notebooklm status -n <notebook_id>
   # Wait until sources show "ready" (poll every 30s, up to 5 min)
   ```
5. Ask targeted grounded questions:
   ```bash
   notebooklm ask "What are the key concepts and main abstractions?" -n <notebook_id>
   notebooklm ask "What are the most important functions/APIs with usage examples?" -n <notebook_id>
   notebooklm ask "What are the common gotchas, limitations, or caveats?" -n <notebook_id>
   ```
6. Present the grounded summary with citations to the user
7. Offer to save to knowledge base (see below)

**Output structure:**
```markdown
# <Topic> — NotebookLM Summary

## Key Concepts
...

## API / Usage Patterns
...

## Gotchas & Limitations
...

## Sources Used
- [source title] — <url>
```

---

### `/notebook research <topic>`

Multi-document research synthesis — compare papers, extract methods, identify gaps.

**Workflow:**
1. Ask user for papers/documents to compare
2. Create or reuse a research notebook
3. Add all sources
4. Wait for processing
5. Ask synthesis questions:
   ```bash
   notebooklm ask "What methods does each paper use? Compare them." -n <notebook_id>
   notebooklm ask "What are the common findings across these papers?" -n <notebook_id>
   notebooklm ask "What gaps or contradictions exist between these sources?" -n <notebook_id>
   ```
6. Optionally generate an audio overview for offline listening:
   ```bash
   # Ask user first — generation takes 5-10 min
   notebooklm generate audio -n <notebook_id>
   notebooklm artifact wait -n <notebook_id>
   notebooklm download audio -n <notebook_id>
   ```
7. Present synthesis and offer to save to knowledge base

---

### `/notebook ask <question>`

Quick grounded Q&A against an existing notebook.

**Workflow:**
1. List notebooks to identify the relevant one:
   ```bash
   notebooklm list --json
   ```
2. Ask the question:
   ```bash
   notebooklm ask "<question>" -n <notebook_id>
   ```
3. Present the grounded answer with citations

---

### `/notebook` (no args)

Interactive mode:
1. `notebooklm list` — show existing notebooks
2. Ask user: select notebook or create new
3. Ask user: what action (prep/research/ask/generate)?
4. Proceed accordingly

---

## Saving to Knowledge Base

After generating any summary, offer to save it:

```
Save this to your knowledge base?
- /knowledge save _technical/<topic>  (for tool docs)
- /knowledge save _bioinformatics/<topic>  (for bio/bioinformatics)
- /knowledge save knowledge/<project>/<topic>  (for project-specific)
```

When saving, add this frontmatter:
```yaml
source-type: notebooklm-grounded
notebooklm-notebook: <notebook_id>
```

---

## Key Rules

- Always use explicit notebook IDs (`-n <notebook_id>`) — never rely on implicit context
- Poll `notebooklm status` before querying — sources must be "ready"
- For long-running generations (audio/video), warn user of expected wait time (5-45 min) and ask confirmation first
- Default to text artifacts; only generate audio/video when user explicitly asks
- Rate limit: if you get a 429 error, wait 5-10 min before retrying
- If auth fails, run `notebooklm login` to refresh credentials
- `--json` flag available on most commands for machine-readable output

## Supported Source Types

- URLs (web pages, documentation sites)
- YouTube videos (auto-transcribed by NotebookLM)
- PDFs (local files or URLs)
- Google Docs / Google Drive files
- Plain text files

## Generation Capabilities

Available via `notebooklm generate <type>`:
- `audio` — podcast-style overview (5-15 min, MP3)
- `video` — visual overview (MP4)
- `slides` — slide deck (PDF or PPTX)
- `quiz` — quiz questions (JSON/Markdown)
- `flashcards` — study flashcards
- `mindmap` — concept map (JSON)
- `report` — written report
