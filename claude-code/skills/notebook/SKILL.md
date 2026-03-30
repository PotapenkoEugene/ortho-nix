---
name: notebook
description: NotebookLM knowledge pipeline — source-grounded document processing, knowledge base extraction, and podcast generation. Runs autonomously during exploration work and on direct user request.
argument-hint: "[project|investigate|prep|research|ask] [topic/question]"
---

# notebook

NotebookLM workflow skill. Source-grounded AI: answers come strictly from uploaded documents with citations — no hallucinations.

Uses the `notebooklm` CLI. Consult `/notebooklm` for the full CLI reference.

## Authentication

One-time setup (runs a browser OAuth flow):
```bash
notebooklm login
```
Credentials stored at `~/.notebooklm/`. Re-run if auth expires.

---

## Autonomous Source Collection (always-on during exploration)

**This is the primary behavior.** During any exploration, planning, or research work — when you encounter valuable documentation URLs, papers, tutorials, GitHub READMEs, or references — process them into NotebookLM without asking permission.

### Workflow

1. **Identify** sources found during research (documentation URLs, papers, tutorials)
2. **Categorize** into a topic group using `{Project}_{topic}` naming:
   - `ADAPTOGENE_gwas`, `ADAPTOGENE_populationGenomics`, `ADAPTOGENE_pipeline`
   - `Desktop_nix`, `Desktop_nvim`, `Desktop_tmux`, `Desktop_claude-code`
   - `soloLTRs_transposable-elements`, `soloLTRs_bioinformatics-tools`
3. **Find or create notebook**:
   ```bash
   # Check project file for existing association
   # NotebookLM: {Project}_{topic} ({notebook_id})

   # If none exists — create silently:
   notebooklm create "{Project}_{topic}" --json
   # Save the returned notebook_id to the project file ## Notes

   # If exists — use the ID from ## Notes
   ```
4. **Add sources**:
   ```bash
   notebooklm source add "<url>" -n <notebook_id>
   ```
5. **Add task** to current task list: "Extract knowledge from {notebook} → knowledge base"
6. **Update project file** `## Notes` section with notebook association:
   ```
   - NotebookLM: {Project}_{topic} ({notebook_id})
   ```

### After adding sources (knowledge extraction)

Wait for processing, then run grounded queries and save to knowledge base:

```bash
# Wait for sources to be ready
notebooklm source list -n <notebook_id> --json
# Poll until all sources show status "ready"

# Query for knowledge
notebooklm ask "<targeted question>" -n <notebook_id>
```

Before creating any knowledge note, search existing notes to avoid redundancy:
```
mcpvault search_notes query="<topic keywords>"
```

Save new knowledge to `~/Orthidian/knowledge/`:
- Project-specific: `knowledge/{project}/`
- Domain reference: `knowledge/_technical/`, `_biology/`, `_bioinformatics/`

### Podcast threshold

When a notebook reaches **>5 sources**, mention to the user:
> "{Project}_{topic} now has N sources — want me to generate a Russian podcast overview?"

Only ask once per session, don't nag.

---

## Modes

### `/notebook project [PROJECTNAME]`

Show and manage all NotebookLM notebooks for a project.

1. Read project file `## Notes` for `NotebookLM:` entries
2. For each notebook: show name, source count (`notebooklm source list -n <id>`), associated knowledge notes
3. Offer actions: query an existing notebook, add new sources, generate artifacts

```bash
notebooklm list --json  # all notebooks
notebooklm source list -n <notebook_id> --json  # sources for a specific notebook
```

---

### `/notebook investigate <topic>`

**Direct investigation mode** — user-initiated deep dive with full pipeline.

1. **Research** the topic: web search, find documentation URLs, papers, tutorials (3-10 sources)
2. **Create notebook** `{Project}_{topic}` automatically
3. **Add all sources**:
   ```bash
   notebooklm source add "<url>" -n <notebook_id>
   # repeat for each source
   ```
4. **Wait** for processing (poll `notebooklm source list`, takes 1-5 min per source)
5. **Extract knowledge** via grounded queries:
   - Core concepts and abstractions
   - Key methods/APIs with examples
   - Gotchas, limitations, failure modes
   - (For research topics): method comparison, common findings, open questions
6. **Save to knowledge base** — check for redundancy first
7. **Update project file** `## Notes` with notebook association
8. **Ask once** about podcast generation (>5 sources threshold)

---

### `/notebook prep <topic>`

Pre-session documentation digest. User provides sources explicitly.

1. Ask user for documentation sources (URLs, PDFs)
2. Find or create `{Project}_{topic}` notebook
3. Add sources, wait for processing
4. Ask targeted summary questions (key concepts, API patterns, gotchas)
5. Present grounded summary with citations
6. Offer to save to knowledge base

---

### `/notebook research <topic>`

Multi-document research synthesis.

1. Ask user for papers/documents to compare
2. Create or reuse notebook
3. Add sources, wait for processing
4. Synthesis questions:
   ```bash
   notebooklm ask "What methods does each paper use? Compare approaches." -n <id>
   notebooklm ask "What are the common findings across these sources?" -n <id>
   notebooklm ask "What gaps or contradictions exist?" -n <id>
   ```
5. Present synthesis, offer knowledge save and podcast

---

### `/notebook ask <question>`

Quick grounded Q&A against an existing notebook.

1. List notebooks to find the relevant one:
   ```bash
   notebooklm list --json
   ```
2. Ask:
   ```bash
   notebooklm ask "<question>" -n <notebook_id>
   ```

---

### `/notebook` (no args)

Interactive: `notebooklm list` → user selects notebook → choose action.

---

## Podcast Generation

Always generate in Russian. Ask before generating (it takes 5-15 min and uses daily quota):

```bash
notebooklm generate audio -n <notebook_id> --language ru
# then poll for completion:
notebooklm artifact list -n <notebook_id> --json  # check status

# download:
notebooklm download audio ~/podcasts/{Project}_{topic}_ru.mp3 -n <notebook_id> -a <artifact_id>
```

Save to: `~/podcasts/{Project}_{topic}_ru.mp3`

---

## Knowledge Note Frontmatter

Every note from NotebookLM sources must include:

```yaml
source-type: notebooklm-grounded
notebooklm-notebook: <notebook_id>
```

Plus standard fields: `status: budding`, `domain`, `created`, `updated`, `tags`, `projects`.

---

## Key Rules

- **Auto-create notebooks** during exploration — never ask permission
- **Auto-add sources** when discovered — never ask permission
- **Do ask** before generating podcasts (time + quota cost)
- Always use explicit notebook IDs (`-n <id>`)
- Poll `notebooklm source list` before querying — sources must be ready
- Check mcpvault before creating knowledge notes (avoid duplicates)
- Rate limit: if 429 error, wait 5-10 min
- Auth failure: run `notebooklm login`
- `--json` flag on all commands for reliable output

## Supported Source Types

URLs, YouTube videos (auto-transcribed), PDFs, Google Docs/Drive files, plain text files

## Generation Capabilities

`notebooklm generate <type> -n <id>`:
- `audio` — podcast MP3 (5-15 min generation)
- `video` — visual overview MP4
- `slides` — slide deck PDF/PPTX
- `quiz`, `flashcards`, `mindmap`, `report`
