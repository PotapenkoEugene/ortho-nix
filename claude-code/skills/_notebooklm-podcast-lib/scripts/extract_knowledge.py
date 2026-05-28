"""
Extract source-grounded knowledge notes from a NotebookLM notebook.

For each requested knowledge type, reads the prompt template, submits it
via `notebooklm ask --save-as-note`, retrieves the saved note, and writes
it to ~/Orthidian/knowledge/{project_slug}/ as a markdown file with frontmatter.
"""

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

LIB = Path(__file__).parent
sys.path.insert(0, str(LIB))

from profile import resolve_knowledge_prompt_path, VALID_KNOWLEDGE_TYPES

KNOWLEDGE_ROOT = Path.home() / "Orthidian" / "knowledge"
TIMEOUT_ASK = 120


def _run_ask(notebook_id: str, prompt: str, note_title: str) -> str | None:
    """
    Run notebooklm ask with --save-as-note. Returns note content or None.
    """
    cmd = [
        "notebooklm", "ask", prompt,
        "-n", notebook_id,
        "--save-as-note",
        "--note-title", note_title,
        "--json",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT_ASK)
    if result.returncode != 0:
        print(f"    Warning: ask failed: {(result.stderr or result.stdout or '').strip()[:200]}")
        return None

    # Try to extract note content from JSON response
    try:
        data = json.loads(result.stdout)
        return data.get("response") or data.get("answer") or data.get("content") or ""
    except Exception:
        # Fall back to raw stdout
        out = result.stdout.strip()
        return out if out else None


def _get_saved_note(notebook_id: str, note_title: str) -> str | None:
    """Retrieve a saved note by title."""
    # List notes to find the one we just saved
    list_result = subprocess.run(
        ["notebooklm", "note", "list", "--json", "-n", notebook_id],
        capture_output=True, text=True, timeout=30,
    )
    if list_result.returncode != 0:
        return None
    try:
        notes = json.loads(list_result.stdout).get("notes", [])
        matching = [n for n in notes if n.get("title") == note_title]
        if not matching:
            return None
        note_id = matching[-1]["id"]
    except Exception:
        return None

    # Get note content
    get_result = subprocess.run(
        ["notebooklm", "note", "get", note_id, "--json", "-n", notebook_id],
        capture_output=True, text=True, timeout=30,
    )
    if get_result.returncode != 0:
        return None
    try:
        data = json.loads(get_result.stdout)
        return data.get("content") or data.get("text") or ""
    except Exception:
        return get_result.stdout.strip() or None


def _make_frontmatter(
    knowledge_type: str,
    notebook_id: str,
    slug: str,
    primary_title: str,
    primary_doi: str,
) -> str:
    today = datetime.now().strftime("%Y-%m-%d")
    tags_map = {
        "briefing": ["briefing", "research-summary"],
        "study-guide": ["study-guide", "education"],
        "faq": ["faq", "research-summary"],
        "timeline": ["timeline", "history"],
        "glossary": ["glossary", "terminology"],
        "concept-inventory": ["concepts", "education"],
        "controversies": ["controversies", "critical-analysis"],
    }
    tags = tags_map.get(knowledge_type, [knowledge_type])
    tags_str = "\n".join(f"  - {t}" for t in tags)

    return f"""---
status: budding
domain: research
created: {today}
updated: {today}
source-type: notebooklm-grounded
notebooklm-notebook: {notebook_id}
knowledge-type: {knowledge_type}
primary-doi: {primary_doi or ""}
tags:
{tags_str}
---

"""


def extract(
    notebook_id: str,
    episode_dir: Path,
    knowledge_types: list[str],
    primary_meta: dict,
    project_slug: str,
    knowledge_subdir: str = "",
) -> dict[str, Path | None]:
    """
    Extract knowledge notes for each type in knowledge_types.

    Args:
        notebook_id: NotebookLM notebook ID
        episode_dir: episode directory (used for local copies)
        knowledge_types: list of knowledge types to extract (from VALID_KNOWLEDGE_TYPES)
        primary_meta: paper metadata dict
        project_slug: slug used in episode dir name (for note naming)
        knowledge_subdir: subdir under ~/Orthidian/knowledge/ (e.g. "Genomics")

    Returns: dict of {type: path_to_written_note | None}
    """
    unknown = set(knowledge_types) - VALID_KNOWLEDGE_TYPES
    if unknown:
        print(f"  Warning: unknown knowledge types: {unknown}. Skipping.")
        knowledge_types = [t for t in knowledge_types if t in VALID_KNOWLEDGE_TYPES]

    if not knowledge_types:
        return {}

    # Determine output directory
    if knowledge_subdir:
        out_dir = KNOWLEDGE_ROOT / knowledge_subdir
    else:
        out_dir = KNOWLEDGE_ROOT / "_research"
    out_dir.mkdir(parents=True, exist_ok=True)

    primary_title = primary_meta.get("title", project_slug)
    primary_doi = primary_meta.get("doi", "")

    results: dict[str, Path | None] = {}
    print(f"\nExtracting knowledge notes: {', '.join(knowledge_types)}")

    for ktype in knowledge_types:
        print(f"  [{ktype}] querying NotebookLM...")
        try:
            prompt_path = resolve_knowledge_prompt_path(ktype)
            prompt = prompt_path.read_text(encoding="utf-8").strip()
        except Exception as e:
            print(f"    Error loading prompt: {e}")
            results[ktype] = None
            continue

        note_title = f"{project_slug}_{ktype}"
        content = _run_ask(notebook_id, prompt, note_title)

        if not content:
            # Try to retrieve from saved notes
            content = _get_saved_note(notebook_id, note_title)

        if not content:
            print(f"    Warning: no content returned for {ktype}")
            results[ktype] = None
            continue

        # Build note
        frontmatter = _make_frontmatter(ktype, notebook_id, project_slug, primary_title, primary_doi)
        header = f"# {primary_title} — {ktype.replace('-', ' ').title()}\n\n"
        note_body = frontmatter + header + content.strip() + "\n"

        # Write to Orthidian knowledge dir
        out_filename = f"{project_slug}-{ktype}.md"
        out_path = out_dir / out_filename
        out_path.write_text(note_body, encoding="utf-8")
        print(f"    Written: {out_path}")

        # Also write a copy to episode dir for reference
        local_copy = episode_dir / f"knowledge-{ktype}.md"
        local_copy.write_text(note_body, encoding="utf-8")

        results[ktype] = out_path

    return results
