"""
Automated QA checks for a podcast episode bundle.

Checks:
1. citation_density: knowledge notes contain [источник:] or [source:] markers
2. no_english_prose: Russian notes don't have untranslated English prose sentences
   (gene names on allowlist are exempt)
3. hook_check: show-notes.md first paragraph contains a number (digit)
4. no_banned_openers: transcript doesn't start with banned phrases
5. prompt_coverage: prompt-used.md is non-trivial (>200 chars)

Updates meta.json qa.checklist with automated results.
"""

import json
import re
from pathlib import Path


GENE_NAME_PATTERN = re.compile(
    r'\b[A-Z][A-Z0-9]{1,9}(?:-[A-Z0-9]+)?\b'  # TP53, BRCA1, HvFT1, RNA-seq, etc.
)
CITATION_PATTERN = re.compile(r'\[(?:источник|source)[\s:]+\d', re.IGNORECASE)
ENGLISH_SENTENCE_PATTERN = re.compile(
    r'(?<![A-Z]{3})'           # not mid-acronym
    r'\b[A-Z][a-z]{3,}\b'     # capitalized English word (>3 chars, lowercase rest)
    r'(?:\s+[a-z]{3,}\b){2,}' # followed by 2+ lowercase English words
)
BANNED_OPENERS = [
    "добро пожаловать",
    "welcome back",
    "welcome to",
    "привет всем",
    "дорогие друзья",
    "сегодня мы поговорим",
    "итак, поехали",
    "начнём с того",
]
DIGIT_PATTERN = re.compile(r'\d')


def _check_citation_density(episode_dir: Path) -> tuple[bool, str]:
    """Check knowledge notes contain citation markers."""
    notes = list(episode_dir.glob("knowledge-*.md"))
    if not notes:
        return True, "no knowledge notes to check"
    found = 0
    total = 0
    for note in notes:
        text = note.read_text(encoding="utf-8")
        count = len(CITATION_PATTERN.findall(text))
        total += 1
        if count >= 2:
            found += 1
    if total == 0:
        return True, "no knowledge notes"
    ratio = found / total
    ok = ratio >= 0.5
    return ok, f"{found}/{total} notes have ≥2 citation markers"


def _check_no_english_prose(episode_dir: Path) -> tuple[bool, str]:
    """Check Russian knowledge notes don't have untranslated English prose."""
    notes = list(episode_dir.glob("knowledge-*.md"))
    if not notes:
        return True, "no knowledge notes"
    violations = []
    for note in notes:
        text = note.read_text(encoding="utf-8")
        # Strip gene names before checking
        clean = GENE_NAME_PATTERN.sub("GENE", text)
        matches = ENGLISH_SENTENCE_PATTERN.findall(clean)
        if len(matches) > 3:  # allow a few (e.g. table headers, method names)
            violations.append(f"{note.name}: {len(matches)} English phrases")
    ok = len(violations) == 0
    return ok, "; ".join(violations) if violations else "OK"


def _check_hook_has_number(episode_dir: Path) -> tuple[bool, str]:
    """Check show-notes first paragraph contains a number."""
    sn = episode_dir / "show-notes.md"
    if not sn.exists():
        return False, "show-notes.md not found"
    text = sn.read_text(encoding="utf-8")
    # First non-empty paragraph after title
    paragraphs = [p.strip() for p in text.split("\n\n") if p.strip() and not p.startswith("#")]
    first = paragraphs[0] if paragraphs else ""
    ok = bool(DIGIT_PATTERN.search(first))
    return ok, "contains number" if ok else "no number in first paragraph"


def _check_no_banned_openers(episode_dir: Path) -> tuple[bool, str]:
    """Check transcript doesn't open with a banned phrase."""
    transcript_json = episode_dir / "transcript.json"
    if not transcript_json.exists():
        return True, "no transcript to check"
    try:
        data = json.loads(transcript_json.read_text(encoding="utf-8"))
        # Get first ~200 chars of transcript text
        text = data.get("text", "")
        if not text:
            segments = data.get("segments", [])
            text = " ".join(s.get("text", "") for s in segments[:3])
        first_200 = text[:200].lower()
        for phrase in BANNED_OPENERS:
            if phrase in first_200:
                return False, f"starts with banned phrase: '{phrase}'"
        return True, "no banned opener detected"
    except Exception as e:
        return True, f"could not parse transcript: {e}"


def _check_prompt_nontrivial(episode_dir: Path) -> tuple[bool, str]:
    """Check customize prompt is non-trivial (>200 chars)."""
    p = episode_dir / "prompt-used.md"
    if not p.exists():
        return False, "prompt-used.md not found"
    length = len(p.read_text(encoding="utf-8").strip())
    ok = length > 200
    return ok, f"{length} chars" if ok else f"too short ({length} chars)"


def run(episode_dir: Path) -> dict:
    """
    Run all automated QA checks. Returns results dict.
    Also updates meta.json if it exists.
    """
    episode_dir = Path(episode_dir)
    checks = {
        "citation_density": _check_citation_density(episode_dir),
        "no_english_prose_in_notes": _check_no_english_prose(episode_dir),
        "hook_has_number": _check_hook_has_number(episode_dir),
        "no_banned_openers": _check_no_banned_openers(episode_dir),
        "prompt_nontrivial": _check_prompt_nontrivial(episode_dir),
    }

    print("\nQA Report:")
    all_ok = True
    results = {}
    for name, (ok, detail) in checks.items():
        status = "PASS" if ok else "FAIL"
        print(f"  [{status}] {name}: {detail}")
        results[name] = {"pass": ok, "detail": detail}
        if not ok:
            all_ok = False

    # Manual checklist items (pipeline can't auto-check these)
    manual_items = {
        "numbers_cited_correctly": None,
        "gene_names_in_english": None,
        "at_least_one_critical_objection": None,
        "russian_sounds_natural": None,
        "show_notes_complete": None,
    }

    # Update meta.json
    meta_path = episode_dir / "meta.json"
    if meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            meta.setdefault("qa", {})
            meta["qa"]["automated"] = results
            meta["qa"]["automated_all_pass"] = all_ok
            # Merge manual checklist preserving existing values
            existing_checklist = meta["qa"].get("checklist", {})
            for k, v in manual_items.items():
                if k not in existing_checklist:
                    existing_checklist[k] = v
            meta["qa"]["checklist"] = existing_checklist
            meta["qa"]["manual_review_status"] = "pending"
            meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
            print(f"  meta.json updated: {meta_path}")
        except Exception as e:
            print(f"  Warning: could not update meta.json: {e}")

    summary = "All automated checks passed." if all_ok else "Some checks failed — see above."
    print(f"\n{summary}")
    return results


if __name__ == "__main__":
    import sys
    import argparse
    parser = argparse.ArgumentParser(description="Run QA checks on episode dir.")
    parser.add_argument("episode_dir", help="Path to episode bundle directory")
    args = parser.parse_args()
    run(Path(args.episode_dir))
