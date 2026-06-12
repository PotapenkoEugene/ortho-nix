"""
Main orchestrator for notebooklm-popsci skill.

Usage:
    python3 pipeline.py <doi_or_pdf> [--companions auto|reviews|research|none]
                        [--length short|default|long] [--force] [--fresh]
                        [--dry-run] [--resume <episode_dir>]
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import textwrap
from datetime import datetime, timezone
from pathlib import Path

# Library scripts live in the same directory as this file
LIB = Path(__file__).parent
sys.path.insert(0, str(LIB))

from slug import make_slug
from resolve_doi import resolve as resolve_doi, PaywallError, DOINotFoundError, OAURLOnlyError
from notebooklm_quota import check as quota_check, QuotaExhaustedError
from select_companions import select as select_companions
from transcribe_groq import transcribe
from show_notes import build as build_show_notes
from profile import load as load_profile, resolve_customize_prompt_path, resolve_style_guide_path
from configure_notebook import configure as configure_notebook
from artifacts import generate_artifacts
from extract_knowledge import extract as extract_knowledge
import qa_report

PODCAST_ROOT = Path.home() / "NotebookLM_pipelines"
PROMPTS_DIR = LIB.parent / "prompts"
EPISODE_LOG = Path.home() / "Orthidian" / "projects" / "podcast-channel" / "podcast-channel.md"


# ──────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────

def _run(cmd: list[str], desc: str, check: bool = True, **kwargs) -> subprocess.CompletedProcess:
    print(f"  $ {' '.join(str(a)[:60] for a in cmd[:4])} ...")
    r = subprocess.run(cmd, text=True, **kwargs)
    if check and r.returncode != 0:
        stderr = r.stderr or "(no captured output — check terminal above)"
        raise RuntimeError(f"{desc} failed (exit {r.returncode}):\n{stderr}")
    return r


def _notebooklm(*args, capture: bool = False, check: bool = True) -> subprocess.CompletedProcess:
    cmd = ["notebooklm"] + list(args)
    kwargs = {"capture_output": capture}
    return _run(cmd, f"notebooklm {args[0]}", check=check, **kwargs)


def _get_notebook_id(title: str) -> str | None:
    """Return existing notebook ID by title, or None."""
    r = subprocess.run(["notebooklm", "list", "--json"],
                       capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        return None
    for nb in json.loads(r.stdout).get("notebooks", []):
        if nb.get("title") == title:
            return nb["id"]
    return None


def _source_title_exists(notebook_id: str, title_substring: str) -> bool:
    """Return True if a source with title_substring already in the notebook."""
    r = subprocess.run(
        ["notebooklm", "source", "list", "--json", "-n", notebook_id],
        capture_output=True, text=True, timeout=30,
    )
    if r.returncode != 0:
        return False
    try:
        sources = json.loads(r.stdout).get("sources", [])
        for s in sources:
            if title_substring.lower() in (s.get("title") or s.get("filename") or "").lower():
                return True
    except Exception:
        pass
    return False


def _add_style_guide(notebook_id: str, style_guide_path: Path):
    """Upload style-guide source if not already present."""
    if _source_title_exists(notebook_id, "style-guide"):
        print("  Style-guide source already in notebook — skipping upload.")
        return
    print(f"  Uploading style-guide source: {style_guide_path.name}")
    result = subprocess.run(
        ["notebooklm", "source", "add", str(style_guide_path), "-n", notebook_id],
        capture_output=True, text=True, timeout=60,
    )
    if result.returncode != 0:
        print(f"  Warning: style-guide upload failed: {(result.stderr or '').strip()[:200]}")
    else:
        print("  Style-guide uploaded.")


def _render_prompt(primary_meta: dict, companions: list[dict], length: str,
                   template_path: Path | None = None) -> str:
    """Render customize prompt template with paper metadata."""
    if template_path is None:
        template_path = PROMPTS_DIR / "popsci-ru.md"
    template = template_path.read_text(encoding="utf-8")

    authors = primary_meta.get("authors", [])
    if len(authors) == 1:
        authors_str = authors[0]
    elif len(authors) == 2:
        authors_str = " и ".join(authors)
    elif len(authors) > 2:
        authors_str = f"{authors[0]} и соавт."
    else:
        authors_str = "авторы"

    length_hints = {"short": "~5 минут", "default": "~10 минут", "long": "~20 минут"}
    length_hint = length_hints.get(length, "~10 минут")

    has_companions = bool(companions)
    companion_titles = [c.get("title", c.get("doi", "")) for c in companions]
    companion_titles_str = "; ".join(f"«{t}»" for t in companion_titles)

    # Simple Jinja2-style substitution (no jinja2 dep needed — variables are predictable)
    prompt = template
    substitutions = {
        "{{ title_en }}": str(primary_meta.get("title") or ""),
        "{{ authors_str }}": authors_str,
        "{{ year }}": str(primary_meta.get("year") or ""),
        "{{ journal }}": str(primary_meta.get("journal") or ""),
        "{{ keywords_str }}": "",
        "{{ length_hint }}": length_hint,
        "{{ has_companions }}": str(has_companions),
        "{{ companion_titles_str }}": companion_titles_str,
    }
    for k, v in substitutions.items():
        prompt = prompt.replace(k, v)

    # Handle {% if has_companions %}...{% endif %} block
    if has_companions:
        prompt = re.sub(r"\{%\s*if has_companions\s*%\}", "", prompt)
        prompt = re.sub(r"\{%\s*endif\s*%\}", "", prompt)
    else:
        prompt = re.sub(r"\{%\s*if has_companions\s*%\}.*?\{%\s*endif\s*%\}", "",
                        prompt, flags=re.DOTALL)
    # Strip remaining template comments
    prompt = re.sub(r"\{#.*?#\}", "", prompt, flags=re.DOTALL)
    return prompt.strip()


def _render_prompt_for_profile(primary_meta: dict, companions: list[dict],
                                length: str, profile: dict) -> str:
    template_path = resolve_customize_prompt_path(profile)
    return _render_prompt(primary_meta, companions, length, template_path)


def _get_audio_artifact_id(notebook_id: str) -> str | None:
    """Return latest audio artifact ID from notebook."""
    r = subprocess.run(
        ["notebooklm", "artifact", "list", "--json", "-n", notebook_id, "--type", "audio"],
        capture_output=True, text=True, timeout=30,
    )
    if r.returncode != 0:
        return None
    artifacts = json.loads(r.stdout).get("artifacts", [])
    audio = [a for a in artifacts if a.get("type_id") == "audio"]
    if not audio:
        return None
    return sorted(audio, key=lambda x: x.get("created_at", ""), reverse=True)[0]["id"]


def _append_episode_log(slug: str, doi: str, ru_title: str, episode_dir: Path):
    """Append episode line to ~/Orthidian/projects/podcast-channel/podcast-channel.md."""
    EPISODE_LOG.parent.mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y-%m-%d")
    ident = f"DOI: {doi}" if doi else "Topic"
    line = f"- {today} [{slug}]({episode_dir}) — {ident} — {ru_title}\n"
    if not EPISODE_LOG.exists():
        EPISODE_LOG.write_text("# Podcast Channel Episodes\n\n", encoding="utf-8")
    with open(EPISODE_LOG, "a", encoding="utf-8") as f:
        f.write(line)
    print(f"  Episode logged: {EPISODE_LOG}")


def _setup_topic_mode(
    topic: str,
    sources_file: str,
    force: bool,
    fresh: bool,
) -> tuple:
    """Load sources JSON, synthesize primary_meta and episode dir for topic mode."""
    src_path = Path(sources_file).expanduser()
    if not src_path.exists():
        raise FileNotFoundError(f"--sources-file not found: {src_path}")
    sources = json.loads(src_path.read_text(encoding="utf-8"))
    if not isinstance(sources, list) or not sources:
        raise ValueError("--sources-file must be a non-empty JSON list of source entries.")

    year = datetime.now().year
    first = sources[0]
    primary_meta = {
        "doi": None,
        "title": topic,
        "authors": [],
        "year": year,
        "journal": None,
        "source": "topic",
        "topic": topic,
        "nominal_primary": {
            "value": first.get("value"),
            "kind": first.get("kind"),
            "title": first.get("title"),
        },
    }

    slug = make_slug("topic", year, topic)
    episode_dir = PODCAST_ROOT / slug

    if episode_dir.exists() and not force and not fresh:
        print(f"\nERROR: Episode dir already exists: {episode_dir}")
        print("Use --force to overwrite or --fresh to restart.")
        raise SystemExit(1)

    if (force or fresh) and episode_dir.exists():
        shutil.rmtree(episode_dir)

    refs_dir = episode_dir / "references"
    refs_dir.mkdir(parents=True, exist_ok=True)
    (refs_dir / "primary.meta.json").write_text(
        json.dumps(primary_meta, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    return primary_meta, sources, slug, episode_dir, refs_dir


def _upload_topic_sources(sources: list, refs_dir: Path, notebook_id: str, slug: str):
    """Upload every entry in the topic sources list to the notebook.

    Scientific-paper DOIs: resolve to PDF (download to refs_dir) and also copy to
    ~/Orthidian/papers/<slug>/ for orthi-brain indexing.
    Non-scientific sources (url/github/youtube/docs/tutorial/article): add by URL.
    """
    papers_dir = Path.home() / "Orthidian" / "papers" / slug
    for i, s in enumerate(sources, 1):
        kind = (s.get("kind") or "").lower()
        category = (s.get("category") or "").lower()
        value = s.get("value") or ""
        local = s.get("local_path") or ""
        label = (s.get("title") or value)[:60]
        print(f"  [{i}/{len(sources)}] ({kind}) {label}")

        if kind in ("pdf", "file"):
            path = Path(local or value).expanduser()
            if not path.exists():
                print(f"    WARNING: file not found, skipping: {path}")
                continue
            _notebooklm("source", "add", str(path), capture=True, check=False)

        elif kind == "doi":
            doi_clean = re.sub(r"^https?://(dx\.)?doi\.org/", "", value.strip())
            dest = refs_dir / f"source_{i:02d}.pdf"
            try:
                resolve_doi(value, dest)
                _notebooklm("source", "add", str(dest), capture=True, check=False)
                # Copy to orthi-brain papers library for indexing
                if dest.exists() and category == "scientific-paper":
                    papers_dir.mkdir(parents=True, exist_ok=True)
                    lib_pdf = papers_dir / f"{i:02d}_{dest.name}"
                    shutil.copy2(str(dest), str(lib_pdf))
                    print(f"    Copied to library: {lib_pdf}")
            except Exception:
                url = f"https://doi.org/{doi_clean}"
                print(f"    PDF unavailable — using URL: {url}")
                _notebooklm("source", "add", url, capture=True, check=False)

        else:
            # url / github / youtube / docs / article / tutorial / workshop → bare URL/string
            _notebooklm("source", "add", value, capture=True, check=False)


# ──────────────────────────────────────────────
# Main pipeline
# ──────────────────────────────────────────────

def run(
    source: str,
    companions_mode: str = "auto",
    length: str = "default",
    force: bool = False,
    fresh: bool = False,
    dry_run: bool = False,
    resume_dir: str = "",
    non_interactive: bool = False,
    profile_name: str = "popsci-ru",
    with_artifacts: list[str] | None = None,
    extract_knowledge_types: list[str] | None = None,
    knowledge_subdir: str = "",
    topic: str = "",
    sources_file: str = "",
) -> Path:
    """Run full pipeline. Returns episode_dir Path."""

    print("\n=== notebooklm-popsci ===\n")

    # ── Load profile ─────────────────────────────
    print(f"Loading profile: {profile_name}")
    profile = load_profile(profile_name)
    profile_format = profile.get("format", "deep-dive")
    profile_length = profile.get("length", "default")
    profile_language = profile.get("language", "ru")
    # --length CLI arg overrides profile, but Russian clamp is enforced in profile.py
    effective_length = length if length != "default" else profile_length
    if profile_language in {"ru"} and effective_length != "default":
        print(f"  [profile] Clamping length '{effective_length}' → 'default' for language='{profile_language}'.")
        effective_length = "default"
    print(f"  format={profile_format}, length={effective_length}, language={profile_language}")


    # ── Resume mode ──────────────────────────────
    if resume_dir:
        episode_dir = Path(resume_dir).expanduser()
        if not episode_dir.exists():
            raise FileNotFoundError(f"Resume dir not found: {episode_dir}")
        meta_path = episode_dir / "meta.json"
        if not meta_path.exists():
            raise FileNotFoundError(f"No meta.json in resume dir. Cannot resume.")
        meta = json.loads(meta_path.read_text())
        print(f"Resuming from: {episode_dir}")
        # Re-enter at companion download step (references/ may be incomplete)
        # For now: re-run from notebook creation onward
        primary_meta = meta["primary"]
        companions_pending = meta.get("_companions_pending", [])
        if companions_pending:
            print("\nMissing companions (manual download required):")
            for c in companions_pending:
                target = episode_dir / c["pdf_path"]
                if not target.exists():
                    print(f"  MISSING: {target}")
                    print(f"    DOI: {c['doi']}")
                    print(f"    Title: {c['title']}")
                    print(f"    Please place PDF at: {target}")
                    raise SystemExit(
                        "\nPlace missing companion PDFs at paths above, then re-run with --resume."
                    )
        companions = meta.get("companions", [])
        slug = meta["slug"]
        source = primary_meta.get("doi", source)
        # Skip to notebook creation
        _run_from_notebook(
            episode_dir, slug, primary_meta, companions,
            effective_length, dry_run, fresh, meta,
            profile=profile,
            with_artifacts=with_artifacts or [],
            extract_knowledge_types=extract_knowledge_types or [],
            knowledge_subdir=knowledge_subdir,
        )
        return episode_dir

    # ── Step 1: Resolve primary ──────────────────
    print("Step 1/8: Resolving primary source...")

    topic_mode = bool(sources_file or topic)
    if topic_mode:
        # Topic mode: synthesize primary_meta from pre-gathered sources list
        print(f"  Topic mode: {topic[:60]}")
        primary_meta, _topic_sources, slug, episode_dir, refs_dir = _setup_topic_mode(
            topic, sources_file, force, fresh
        )
        primary_meta["_sources"] = _topic_sources
        primary_url_source = None
        primary_pdf = None
        print(f"  slug={slug}, {len(_topic_sources)} source(s) to upload")
    else:
        # Pre-resolve to get slug before creating episode_dir
        meta_tmp_dest = Path("/tmp") / "popsci_primary_tmp.pdf"
        primary_url_source = None  # set when PDF unavailable but OA URL exists
        try:
            primary_meta = resolve_doi(source, meta_tmp_dest)
        except PaywallError as e:
            print(f"\nERROR (Paywall): {e}")
            print("Provide the PDF path directly instead of a DOI.")
            raise SystemExit(1)
        except OAURLOnlyError as e:
            print(f"  PDF blocked by server — using URL source: {e.url}")
            primary_url_source = e.url
            # Still need CrossRef metadata for slug generation
            from resolve_doi import _crossref_meta
            doi_clean = re.sub(r"^https?://(dx\.)?doi\.org/", "", source.strip())
            primary_meta = _crossref_meta(doi_clean)
            primary_meta["doi"] = doi_clean
            primary_meta["source"] = "url"
            meta_tmp_dest = None  # no PDF file
        except DOINotFoundError as e:
            print(f"\nERROR: {e}")
            raise SystemExit(1)

        # Generate slug and episode dir
        authors = primary_meta.get("authors", [])
        first_author = authors[0] if authors else "unknown"
        year = primary_meta.get("year") or "0000"
        title = primary_meta.get("title", "paper")
        doi = primary_meta.get("doi") or source

        slug = make_slug(first_author, year, title)
        episode_dir = PODCAST_ROOT / slug

        if episode_dir.exists() and not force and not fresh:
            print(f"\nERROR: Episode dir already exists: {episode_dir}")
            print("Use --force to overwrite or --fresh to restart.")
            raise SystemExit(1)

        if (force or fresh) and episode_dir.exists():
            shutil.rmtree(episode_dir)

        refs_dir = episode_dir / "references"
        refs_dir.mkdir(parents=True, exist_ok=True)
        primary_pdf = refs_dir / "primary.pdf"

        if meta_tmp_dest and meta_tmp_dest.exists():
            # Move PDF from tmp to final location
            shutil.move(str(meta_tmp_dest), str(primary_pdf))
            primary_meta["pdf_path"] = "references/primary.pdf"
        else:
            primary_meta["url_source"] = primary_url_source

        primary_meta["doi"] = doi

        # Write primary metadata
        (refs_dir / "primary.meta.json").write_text(
            json.dumps(primary_meta, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(f"  Primary: {primary_meta.get('title', doi)[:60]}")
        if primary_url_source:
            print(f"  URL source: {primary_url_source}")
        else:
            print(f"  Saved: {primary_pdf}")

    # ── Step 2: Quota check ──────────────────────
    print("\nStep 2/8: Checking NotebookLM quota...")
    if not dry_run:
        try:
            used = quota_check()
            print(f"  Quota OK: {used}/3 used today.")
        except QuotaExhaustedError as e:
            print(f"\nQUOTA: {e}")
            raise SystemExit(1)
    else:
        print("  [dry-run] Skipping quota check.")

    # ── Step 3: Notebook create / reuse ─────────
    print("\nStep 3/8: Setting up NotebookLM notebook...")
    nb_title = f"popsci_{slug}"
    notebook_id = _get_notebook_id(nb_title)
    if notebook_id:
        if fresh:
            print(f"  Deleting old notebook: {nb_title}")
            _notebooklm("delete", "--yes", "-n", notebook_id, capture=True)
            notebook_id = None
        else:
            print(f"  Reusing existing notebook: {nb_title} ({notebook_id})")
            _notebooklm("use", notebook_id, capture=True)

    if not notebook_id:
        print(f"  Creating notebook: {nb_title}")
        _notebooklm("create", nb_title, capture=True)
        notebook_id = _get_notebook_id(nb_title)
        if not notebook_id:
            raise RuntimeError("Could not find notebook ID after creation.")
        _notebooklm("use", notebook_id, capture=True)
        print(f"  Notebook ID: {notebook_id}")

    # ── Step 4: Add source(s) to notebook ────────
    print("\nStep 4/8: Adding source(s) to notebook...")
    if topic_mode:
        _upload_topic_sources(primary_meta.get("_sources", []), refs_dir, notebook_id, slug)
    elif primary_url_source:
        url_candidates = [primary_url_source]
        if primary_meta.get("doi"):
            url_candidates.append(f"https://doi.org/{primary_meta['doi']}")
        for url in url_candidates:
            try:
                _notebooklm("source", "add", url, capture=True)
                break
            except Exception as e:
                print(f"  URL source failed ({url}): {e} — trying next...")
        else:
            raise RuntimeError(f"Could not add primary source to NotebookLM (tried {url_candidates})")
    else:
        _notebooklm("source", "add", str(primary_pdf), capture=True)
    _notebooklm("source", "wait", capture=True, check=False)

    # ── Enrich metadata for local PDFs via NotebookLM ──
    if not topic_mode and primary_meta.get("source") == "local" and not primary_meta.get("title_resolved"):
        print("  Enriching metadata from NotebookLM (local PDF)...")
        try:
            r = subprocess.run(
                ["notebooklm", "ask",
                 "What is the exact title of this paper, who are the authors (surnames only), "
                 "what year was it published, and what journal? Answer in English, one line each: "
                 "Title: ...\nAuthors: ...\nYear: ...\nJournal: ...",
                 "-n", notebook_id],
                capture_output=True, text=True, timeout=60,
            )
            raw = r.stdout + r.stderr
            for line in raw.splitlines():
                if line.startswith("Title:"):
                    val = line.split(":", 1)[1].strip()
                    if val and not val.endswith(".pdf"):  # ignore if NLM echoed filename
                        primary_meta["title"] = val
                elif line.startswith("Authors:"):
                    authors_raw = line.split(":", 1)[1].strip()
                    parsed = [a.strip() for a in re.split(r",|;| and ", authors_raw) if a.strip()]
                    if parsed:
                        primary_meta["authors"] = parsed
                elif line.startswith("Year:"):
                    m = re.search(r"\d{4}", line)
                    if m:
                        primary_meta["year"] = int(m.group())
                elif line.startswith("Journal:"):
                    val = line.split(":", 1)[1].strip()
                    if val:
                        primary_meta["journal"] = val
            primary_meta["title_resolved"] = True
            # Regenerate slug with real metadata
            authors = primary_meta.get("authors", [])
            first_author = authors[0] if authors else "unknown"
            year = primary_meta.get("year") or "0000"
            title = primary_meta.get("title", "paper")
            new_slug = make_slug(first_author, year, title)
            if new_slug != slug:
                import os
                new_episode_dir = PODCAST_ROOT / new_slug
                os.rename(episode_dir, new_episode_dir)
                episode_dir = new_episode_dir
                refs_dir = episode_dir / "references"
                primary_pdf = refs_dir / "primary.pdf"
                slug = new_slug
                nb_title = f"popsci_{slug}"
                _notebooklm("rename", nb_title, "-n", notebook_id, capture=True, check=False)
                print(f"  Updated slug: {slug}")
            # Update primary meta file
            primary_meta["pdf_path"] = "references/primary.pdf"
            (refs_dir / "primary.meta.json").write_text(
                json.dumps(primary_meta, indent=2, ensure_ascii=False), encoding="utf-8"
            )
            print(f"  Title: {primary_meta.get('title', '')[:70]}")
        except Exception as e:
            print(f"  Warning: metadata enrichment failed ({e}). Proceeding with filename as title.")

    doi = primary_meta.get("doi") or source
    title = primary_meta.get("title") or slug

    # ── Step 5: Companion selection ──────────────
    companions: list[dict] = []
    if topic_mode:
        print("\nStep 5/8: Companions skipped (topic mode — sources are pre-specified).")
    elif companions_mode != "none":
        print(f"\nStep 5/8: Selecting companion papers (mode={companions_mode})...")
        candidates = select_companions(
            doi, title, notebook_id, mode=companions_mode
        )

        if candidates:
            print("\n  Companion candidates:")
            for i, c in enumerate(candidates, 1):
                oa_tag = "OA" if c.get("is_oa") else "PAYWALLED"
                rev_tag = "review" if c.get("type") == "review" else "research"
                print(f"  {i}. [{oa_tag}][{rev_tag}] {c.get('title', c['doi'])[:70]}")
                print(f"     DOI: {c['doi']}")
                print(f"     {c.get('rationale', '')}")
            print()

            if non_interactive:
                print("  Non-interactive: accepting all companion candidates.")
            else:
                # Interactive confirmation
                print("  Confirm companions to download? [enter = all | space-sep nums to include | n = none]")
                try:
                    answer = input("  > ").strip()
                    if answer.lower() in ("n", "no", "none"):
                        candidates = []
                    elif answer:
                        nums = [int(x) - 1 for x in answer.split() if x.isdigit()]
                        candidates = [candidates[i] for i in nums if 0 <= i < len(candidates)]
                except (EOFError, KeyboardInterrupt):
                    candidates = []

        if candidates:
            print(f"\n  Downloading {len(candidates)} companion(s)...")
            missing = []
            for i, c in enumerate(candidates, 1):
                c_doi = c["doi"]
                c_dest = refs_dir / f"companion_{i}.pdf"
                from resolve_doi import resolve as _res, PaywallError as _PE, DOINotFoundError as _NF, OAURLOnlyError as _OAUE
                try:
                    c_meta = _res(c_doi, c_dest)
                    c_meta.update({
                        "type": c.get("type"),
                        "rationale": c.get("rationale"),
                        "pdf_path": f"references/companion_{i}.pdf",
                    })
                    (refs_dir / f"companion_{i}.meta.json").write_text(
                        json.dumps(c_meta, indent=2, ensure_ascii=False)
                    )
                    companions.append(c_meta)
                    print(f"    Downloaded: {c_meta.get('title', c_doi)[:60]}")
                except _OAUE as e:
                    print(f"    PDF blocked, using URL: {e.url}")
                    from resolve_doi import _crossref_meta
                    doi_clean = re.sub(r"^https?://(dx\.)?doi\.org/", "", c_doi.strip())
                    c_meta_url = _crossref_meta(doi_clean)
                    c_meta_url["doi"] = doi_clean
                    c_meta_url["source"] = "url"
                    c_meta_url["url_source"] = e.url
                    c_meta_url.update({
                        "type": c.get("type"),
                        "rationale": c.get("rationale"),
                        "pdf_path": None,
                    })
                    (refs_dir / f"companion_{i}.meta.json").write_text(
                        json.dumps(c_meta_url, indent=2, ensure_ascii=False)
                    )
                    companions.append(c_meta_url)
                    print(f"    URL source: {c_meta_url.get('title', c_doi)[:60]}")
                except (_PE, _NF) as e:
                    print(f"\n    CANNOT RETRIEVE companion {i}: {c_doi}")
                    print(f"    {e}")
                    print(f"    Please download manually and place at: {c_dest}")
                    missing.append({"doi": c_doi, "title": c.get("title", ""), "pdf_path": f"references/companion_{i}.pdf"})

            if missing:
                # Save pending list for --resume
                meta_partial = {
                    "schema_version": "1.0",
                    "skill": "notebooklm-popsci",
                    "slug": slug,
                    "primary": primary_meta,
                    "_companions_pending": missing,
                }
                (episode_dir / "meta.json").write_text(
                    json.dumps(meta_partial, indent=2, ensure_ascii=False)
                )
                raise SystemExit(
                    f"\nStopped: {len(missing)} companion(s) could not be retrieved automatically.\n"
                    "Place PDFs at the paths shown above, then run:\n"
                    f"  /notebooklm-popsci --resume {episode_dir}"
                )

            # Add companions to notebook
            for i, c in enumerate(companions, 1):
                if c.get("url_source"):
                    # Try the OA URL; fall back to doi.org landing page; skip on failure
                    url_candidates = [c["url_source"]]
                    if c.get("doi"):
                        url_candidates.append(f"https://doi.org/{c['doi']}")
                    added = False
                    for url in url_candidates:
                        try:
                            _notebooklm("source", "add", url, capture=True)
                            added = True
                            break
                        except Exception:
                            continue
                    if not added:
                        print(f"    Skipping companion {i}: URL source not accepted by NotebookLM")
                else:
                    c_pdf = refs_dir / f"companion_{i}.pdf"
                    _notebooklm("source", "add", str(c_pdf), capture=True)
            _notebooklm("source", "wait", capture=True, check=False)
        else:
            print("  No companions selected.")

    else:
        print("\nStep 5/8: Companions skipped (--companions none).")

    # ── Step 5b: Upload style-guide source ──────
    style_guide_path = resolve_style_guide_path(profile)
    if style_guide_path and not dry_run:
        _add_style_guide(notebook_id, style_guide_path)

    # ── Step 5c: Configure notebook persona ─────
    if not dry_run:
        print("  Configuring notebook persona...")
        configure_notebook(notebook_id, profile)

    # ── Step 6: Render prompt ────────────────────
    print("\nStep 6/8: Rendering customize prompt...")
    prompt = _render_prompt_for_profile(primary_meta, companions, effective_length, profile)
    (episode_dir / "prompt-used.md").write_text(prompt, encoding="utf-8")
    print(f"  Prompt: {episode_dir / 'prompt-used.md'} ({len(prompt)} chars)")

    _run_from_notebook(episode_dir, slug, primary_meta, companions,
                       effective_length, dry_run, fresh, None, notebook_id, prompt,
                       profile=profile,
                       with_artifacts=with_artifacts or [],
                       extract_knowledge_types=extract_knowledge_types or [],
                       knowledge_subdir=knowledge_subdir)
    return episode_dir


def _run_from_notebook(
    episode_dir: Path,
    slug: str,
    primary_meta: dict,
    companions: list[dict],
    length: str,
    dry_run: bool,
    fresh: bool,
    existing_meta: dict | None,
    notebook_id: str = "",
    prompt: str = "",
    profile: dict | None = None,
    with_artifacts: list[str] | None = None,
    extract_knowledge_types: list[str] | None = None,
    knowledge_subdir: str = "",
):
    """Steps 7–11: generate audio, transcribe, show-notes, meta.json, artifacts, knowledge."""
    if profile is None:
        profile = {}
    if with_artifacts is None:
        with_artifacts = []
    if extract_knowledge_types is None:
        extract_knowledge_types = []
    profile_format = profile.get("format", "deep-dive")
    profile_language = profile.get("language", "ru")

    if not notebook_id:
        # Recover from meta
        nb_info_path = episode_dir / "notebook-info.json"
        if nb_info_path.exists():
            notebook_id = json.loads(nb_info_path.read_text()).get("notebook_id", "")
        if not notebook_id:
            raise RuntimeError("No notebook_id available. Re-run from start.")

    if not prompt:
        prompt_path = episode_dir / "prompt-used.md"
        if prompt_path.exists():
            prompt = prompt_path.read_text()

    # ── Step 7: Generate audio ───────────────────
    audio_path = episode_dir / "audio.mp3"
    artifact_id = ""

    if dry_run:
        print("\nStep 7/8: [dry-run] Skipping audio generation.")
        print(f"  To generate manually, run:")
        print(f"    notebooklm use {notebook_id}")
        print(f"    notebooklm generate audio '<prompt>' --format {profile_format} --length {length} --wait")
        print(f"    notebooklm download audio {audio_path}")
        print(f"\nPrompt to paste (also in {episode_dir}/prompt-used.md):\n")
        print(textwrap.indent(prompt, "    "))
        print(f"\nEpisode dir: {episode_dir}")
        print(f"\n[dry-run] Bundle prepared (no audio). Dir: {episode_dir}")
        return
    else:
        print("\nStep 7/8: Generating audio (this may take 5–20 minutes)...")
        _notebooklm("use", notebook_id, capture=True)
        # Submit generation without waiting, get artifact ID from JSON
        gen_result = _notebooklm(
            "generate", "audio", prompt,
            "--format", profile_format,
            "--length", length,
            "--retry", "3",
            "--no-wait", "--json",
            capture=True,
        )
        try:
            gen_data = json.loads(gen_result.stdout)
            artifact_id = gen_data.get("id") or gen_data.get("artifact_id") or ""
        except Exception:
            artifact_id = ""
        if not artifact_id:
            # Fallback: grab latest artifact ID from list
            artifact_id = _get_audio_artifact_id(notebook_id) or ""

        if artifact_id:
            print(f"  Generation started (artifact: {artifact_id}). Waiting up to 45 min...")
            _notebooklm(
                "artifact", "wait", artifact_id,
                "-n", notebook_id,
                "--timeout", "2700",
                "--interval", "15",
                capture=False,
            )
        else:
            print("  Generation started. Waiting 20 minutes...")
            import time as _time
            _time.sleep(1200)

        print("  Audio generated. Downloading...")
        _notebooklm("download", "audio", str(audio_path), "--latest", capture=False)
        if not artifact_id:
            artifact_id = _get_audio_artifact_id(notebook_id) or ""
        print(f"  Audio: {audio_path} ({audio_path.stat().st_size // 1024} KB)")

        # Write notebook-info
        nb_info = {
            "notebook_id": notebook_id,
            "artifact_id": artifact_id,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "language": profile_language,
            "format": profile_format,
            "length_setting": length,
            "profile": profile.get("name", "popsci-ru"),
        }
        (episode_dir / "notebook-info.json").write_text(
            json.dumps(nb_info, indent=2)
        )

        # ── Step 8: Transcribe ───────────────────
        print("\nStep 8/8: Transcribing audio...")
        transcript_data = transcribe(audio_path, language="ru")
        duration = transcript_data.get("duration", 0)
        print(f"  Duration: {duration:.0f}s")

        # ── Get Russian title from NotebookLM ────
        print("  Getting Russian title...")
        try:
            r = subprocess.run(
                ["notebooklm", "ask",
                 f"Предложи короткое (5-8 слов) название выпуска подкаста на русском языке "
                 f"для статьи '{primary_meta.get('title', '')}'. Только название, без объяснений.",
                 "-n", notebook_id],
                capture_output=True, text=True, timeout=60,
            )
            ru_title = (r.stdout + r.stderr).strip().split("\n")[0].strip('"\'')[:80]
        except Exception:
            ru_title = ""

        # ── Step 9: Show-notes ───────────────────
        print("  Building show-notes...")
        try:
            nb_summary_r = subprocess.run(
                ["notebooklm", "ask",
                 "Кратко (2-3 предложения на русском) опиши суть этой статьи и главный вывод. "
                 "Используй конкретные числа и не добавляй ничего, чего нет в источнике.",
                 "-n", notebook_id],
                capture_output=True, text=True, timeout=60,
            )
            nb_summary = (nb_summary_r.stdout + nb_summary_r.stderr).strip()
        except Exception:
            nb_summary = ""

        build_show_notes(
            episode_dir=episode_dir,
            primary_meta=primary_meta,
            companions=companions,
            transcript_json=transcript_data,
            notebook_summary=nb_summary,
            ru_title=ru_title,
        )

        # ── Step 10: Write meta.json ─────────────
        meta = {
            "schema_version": "1.0",
            "skill": "notebooklm-popsci",
            "slug": slug,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "language": "ru",
            "primary": primary_meta,
            "companions": companions,
            "audio": {
                "path": "audio.mp3",
                "duration_sec": round(duration, 1),
                "format": profile_format,
                "length_setting": length,
                "language": profile_language,
                "notebooklm_artifact_id": artifact_id,
            },
            "profile": profile.get("name", "popsci-ru"),
            "transcript": {
                "json_path": "transcript.json",
                "srt_path": "transcript.srt",
                "engine": "groq/whisper-large-v3-turbo",
            },
            "show_notes_path": "show-notes.md",
            "prompt_path": "prompt-used.md",
            "qa": {
                "manual_review_status": "pending",
                "checklist": {
                    "numbers_cited_correctly": None,
                    "gene_names_in_english": None,
                    "at_least_one_critical_objection": None,
                    "russian_sounds_natural": None,
                    "show_notes_complete": None,
                },
            },
        }
        # Topic-mode extras: inject topic title and flat sources list
        if primary_meta.get("source") == "topic":
            meta["topic"] = primary_meta.get("topic", "")
            meta["sources"] = primary_meta.get("_sources", [])
        (episode_dir / "meta.json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False)
        )

        # ── Step 10b: Artifacts ──────────────────
        if with_artifacts:
            artifact_results = generate_artifacts(notebook_id, episode_dir, with_artifacts)
            meta["artifacts"] = {
                k: str(v) if v else None for k, v in artifact_results.items()
            }
            (episode_dir / "meta.json").write_text(
                json.dumps(meta, indent=2, ensure_ascii=False)
            )

        # ── Step 10c: Knowledge extraction ──────
        knowledge_types = extract_knowledge_types or profile.get("knowledge_extraction_defaults", [])
        if knowledge_types:
            knowledge_results = extract_knowledge(
                notebook_id=notebook_id,
                episode_dir=episode_dir,
                knowledge_types=knowledge_types,
                primary_meta=primary_meta,
                project_slug=slug,
                knowledge_subdir=knowledge_subdir,
            )
            meta["knowledge_notes"] = {
                k: str(v) if v else None for k, v in knowledge_results.items()
            }
            (episode_dir / "meta.json").write_text(
                json.dumps(meta, indent=2, ensure_ascii=False)
            )

        # ── Step 10d: Automated QA ───────────────
        print("\nRunning automated QA checks...")
        qa_report.run(episode_dir)

        # ── Step 11: Episode log ─────────────────
        _append_episode_log(slug, primary_meta.get("doi") or "", ru_title, episode_dir)

        print(f"\nEpisode dir: {episode_dir}")
        print(f"\n✓ Episode bundle: {episode_dir}")
        print(f"  Listen:    mpv {episode_dir}/audio.mp3")
        print(f"  Captions:  {episode_dir}/transcript.srt")
        print(f"  Show-notes:{episode_dir}/show-notes.md")
        print(f"\nQA checklist in meta.json. Mark items before publishing.")


# ──────────────────────────────────────────────
# CLI entry point
# ──────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Generate NotebookLM podcast from a paper (DOI or PDF)."
    )
    parser.add_argument("source", nargs="?", help="DOI or local PDF path")
    parser.add_argument("--topic", default="",
                        help="Topic title for explicit-sources mode (bypasses DOI resolution)")
    parser.add_argument("--sources-file", default="", metavar="PATH",
                        help="JSON file: pre-gathered source entries [{value,kind,category,title,authority_note,local_path}]")
    parser.add_argument("--profile", default="popsci-ru",
                        help="Pipeline profile name (default: popsci-ru)")
    parser.add_argument("--companions", default="auto",
                        choices=["auto", "reviews", "research", "none"])
    parser.add_argument("--length", default="default",
                        choices=["short", "default", "long"],
                        help="Audio length hint (Russian: always clamped to 'default')")
    parser.add_argument("--force", action="store_true",
                        help="Proceed even if episode dir exists")
    parser.add_argument("--fresh", action="store_true",
                        help="Delete and recreate notebook from scratch")
    parser.add_argument("--dry-run", action="store_true",
                        help="Prepare everything but skip audio generation")
    parser.add_argument("--resume", metavar="EPISODE_DIR",
                        help="Resume from partial episode after manual companion download")
    parser.add_argument("--non-interactive", action="store_true",
                        help="Skip interactive prompts (for bot/script use)")
    parser.add_argument("--with-artifacts", default="",
                        help="Comma-separated artifacts to generate: mind-map,flashcards,quiz")
    parser.add_argument("--extract-knowledge", default="",
                        help="Comma-separated knowledge types: briefing,glossary,faq,study-guide,timeline,concept-inventory,controversies")
    parser.add_argument("--knowledge-subdir", default="",
                        help="Subdirectory under ~/Orthidian/knowledge/ for extracted notes")
    args = parser.parse_args()

    _topic_mode = bool(args.sources_file or args.topic)
    if _topic_mode and args.source:
        parser.error("Provide EITHER a positional DOI/PDF source OR --topic/--sources-file, not both.")
    if _topic_mode and not args.sources_file:
        parser.error("--topic requires --sources-file <path.json>.")
    if _topic_mode and not args.topic:
        parser.error("--sources-file requires --topic \"<title>\".")
    if not args.source and not args.resume and not _topic_mode:
        parser.error("Provide a DOI/PDF source, --topic + --sources-file, or --resume <dir>.")

    artifacts = [a.strip() for a in args.with_artifacts.split(",") if a.strip()]
    knowledge = [k.strip() for k in args.extract_knowledge.split(",") if k.strip()]

    run(
        source=args.source or "",
        companions_mode=args.companions,
        length=args.length,
        force=args.force,
        fresh=args.fresh,
        dry_run=args.dry_run,
        resume_dir=args.resume or "",
        non_interactive=args.non_interactive,
        profile_name=args.profile,
        with_artifacts=artifacts,
        extract_knowledge_types=knowledge,
        knowledge_subdir=args.knowledge_subdir,
        topic=args.topic,
        sources_file=args.sources_file,
    )


if __name__ == "__main__":
    main()
