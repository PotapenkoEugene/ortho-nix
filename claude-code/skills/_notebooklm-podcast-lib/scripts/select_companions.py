"""Adaptive companion paper selection for notebooklm-popsci skill."""

import json
import re
import subprocess
import sys
import time
from pathlib import Path

import requests

UNPAYWALL_EMAIL = "selfisheugenes@gmail.com"
HEADERS = {"User-Agent": f"notebooklm-popsci/1.0 (mailto:{UNPAYWALL_EMAIL})"}
TIMEOUT = 20
MAX_COMPANIONS = 4


def _crossref_references(doi: str) -> list[dict]:
    """Fetch reference list from CrossRef for a DOI."""
    try:
        r = requests.get(
            f"https://api.crossref.org/works/{doi}",
            headers=HEADERS, timeout=TIMEOUT,
        )
        if r.status_code != 200:
            return []
        refs = r.json().get("message", {}).get("reference", [])
        out = []
        for ref in refs:
            ref_doi = ref.get("DOI", "")
            if ref_doi:
                out.append({"doi": ref_doi.lower(), "unstructured": ref.get("unstructured", "")})
        return out
    except Exception:
        return []


def _crossref_meta_bulk(dois: list[str]) -> dict[str, dict]:
    """Fetch metadata for a list of DOIs. Returns {doi: meta}."""
    results = {}
    for doi in dois:
        try:
            r = requests.get(
                f"https://api.crossref.org/works/{doi}",
                headers=HEADERS, timeout=TIMEOUT,
            )
            if r.status_code != 200:
                continue
            w = r.json().get("message", {})
            title_list = w.get("title", [])
            title = title_list[0] if title_list else ""
            authors = [a.get("family", "") or a.get("name", "") for a in w.get("author", [])]
            authors = [a for a in authors if a]
            year = None
            for df in ("published", "published-print", "issued"):
                dp = w.get(df, {}).get("date-parts", [[]])
                if dp and dp[0]:
                    year = dp[0][0]
                    break
            journal_list = w.get("container-title", [])
            journal = journal_list[0] if journal_list else ""
            cites = w.get("is-referenced-by-count", 0)
            # Review detection: check type subtype or title keywords
            cr_type = w.get("type", "")
            subtypes = w.get("subtype", "")
            is_review = (
                "review" in subtypes.lower() if subtypes else False
                or bool(re.search(r"\b(review|обзор|перспектива|meta-analysis)\b", title.lower()))
            )
            results[doi] = {
                "doi": doi,
                "title": title,
                "authors": authors,
                "year": year,
                "journal": journal,
                "citation_count": cites,
                "is_review": is_review,
                "cr_type": cr_type,
            }
            time.sleep(0.1)
        except Exception:
            continue
    return results


def _is_oa(doi: str) -> bool:
    """Quick OA check via Unpaywall."""
    try:
        r = requests.get(
            f"https://api.unpaywall.org/v2/{doi}?email={UNPAYWALL_EMAIL}",
            headers=HEADERS, timeout=TIMEOUT,
        )
        if r.status_code != 200:
            return False
        return r.json().get("is_oa", False)
    except Exception:
        return False


def _score(meta: dict, mode: str) -> float:
    """Score a candidate by mode + attributes."""
    score = 0.0
    if meta.get("is_review"):
        if mode in ("reviews", "auto"):
            score += 10.0
    else:
        if mode == "research":
            score += 10.0
        elif mode == "auto":
            score += 5.0
    cites = meta.get("citation_count", 0)
    score += min(cites / 100, 5.0)  # citation bonus, capped at 5
    year = meta.get("year") or 0
    if year >= 2020:
        score += 2.0
    elif year >= 2015:
        score += 1.0
    return score


def _notebooklm_ask_companions(notebook_id: str, primary_title: str) -> list[str]:
    """
    Ask NotebookLM (via existing notebook) which papers would enrich context.
    Returns list of suggested DOIs (may be unreliable — used as hints only).
    """
    query = (
        f"The paper '{primary_title}' is the primary source. "
        "Which 2-4 closely related published reviews or key methods papers (with DOIs if possible) "
        "would provide essential context for a popular-science podcast listener? "
        "List only papers that are directly cited in the source or are the canonical references for the methods used."
    )
    try:
        result = subprocess.run(
            ["notebooklm", "ask", query, "-n", notebook_id],
            capture_output=True, text=True, timeout=60,
        )
        text = result.stdout + result.stderr
        dois = re.findall(r"10\.\d{4,9}/\S+", text)
        return [d.rstrip(".,)\"'") for d in dois]
    except Exception:
        return []


def _density_check(notebook_id: str) -> bool:
    """
    Returns True if paper needs companion context.
    Ask NotebookLM: is this self-contained enough for pop-sci podcast?
    """
    query = (
        "Оцени: достаточно ли этой статьи как самостоятельного источника для 10-минутного "
        "научно-популярного подкаста для биологов, или ей необходим внешний контекст "
        "(обзор методов, предыдущий ключевой результат, обзор области)? "
        "Ответь одним словом: ДА (достаточно) или НЕТ (нужен контекст)."
    )
    try:
        result = subprocess.run(
            ["notebooklm", "ask", query, "-n", notebook_id],
            capture_output=True, text=True, timeout=60,
        )
        text = (result.stdout + result.stderr).upper()
        if "НЕТ" in text or "NO" in text or "НУЖЕН" in text:
            return True  # needs companions
        return False
    except Exception:
        return False  # assume self-contained on error


def select(
    primary_doi: str,
    primary_title: str,
    notebook_id: str,
    mode: str = "auto",
    max_n: int = MAX_COMPANIONS,
) -> list[dict]:
    """
    Select 1–max_n companion papers.

    Returns list of candidate dicts for USER CONFIRMATION:
        {doi, title, authors, year, journal, type, rationale, is_oa, score}

    Caller MUST present list to user and confirm before downloading.
    On mode='none', returns [].
    """
    if mode == "none":
        return []

    # Step 1: density check (auto mode only)
    if mode == "auto":
        needs_context = _density_check(notebook_id)
        if not needs_context:
            print("  Density check: paper is self-contained. Skipping companions.")
            return []
        print("  Density check: paper needs context. Selecting companions...")

    # Step 2: gather candidate DOIs
    ref_dois = [r["doi"] for r in _crossref_references(primary_doi)]
    nlm_dois = _notebooklm_ask_companions(notebook_id, primary_title)

    # Combine, deduplicate, remove primary
    primary_doi_clean = primary_doi.lower().strip()
    all_dois = list({d.lower().strip() for d in ref_dois + nlm_dois
                     if d.lower().strip() != primary_doi_clean})[:40]  # cap API calls

    if not all_dois:
        print("  No candidate companions found via CrossRef/NotebookLM.")
        return []

    # Step 3: fetch metadata + OA status
    print(f"  Checking {len(all_dois)} candidate DOIs...")
    meta_map = _crossref_meta_bulk(all_dois)

    # Filter by mode + minimum quality gate
    MIN_CITATIONS = 10  # reject papers with very few citations unless from NLM
    candidates = []
    for doi, meta in meta_map.items():
        if mode == "reviews" and not meta.get("is_review"):
            continue
        if mode == "research" and meta.get("is_review"):
            continue
        # Skip low-citation papers unless NLM specifically recommended them
        is_nlm_rec = doi.lower() in [d.lower() for d in nlm_dois]
        if meta.get("citation_count", 0) < MIN_CITATIONS and not is_nlm_rec:
            continue
        oa = _is_oa(doi)
        meta["is_oa"] = oa
        meta["score"] = _score(meta, mode)
        candidates.append(meta)
        time.sleep(0.2)

    # Sort by score, take top max_n
    candidates.sort(key=lambda x: x["score"], reverse=True)
    top = candidates[:max_n]

    # Add rationale text
    for c in top:
        parts = []
        if c.get("is_review"):
            parts.append("обзорная статья")
        parts.append(f"{c.get('citation_count', 0)} цитирований")
        if c.get("doi") in [d.lower() for d in ref_dois]:
            parts.append("процитирована в основной статье")
        if c.get("doi") in [d.lower() for d in nlm_dois]:
            parts.append("рекомендована NotebookLM")
        c["rationale"] = "; ".join(parts)
        c["type"] = "review" if c.get("is_review") else "research"

    return top


if __name__ == "__main__":
    doi = sys.argv[1] if len(sys.argv) > 1 else "10.7554/eLife.93210"
    title = sys.argv[2] if len(sys.argv) > 2 else "Test paper"
    notebook_id = sys.argv[3] if len(sys.argv) > 3 else ""
    mode = sys.argv[4] if len(sys.argv) > 4 else "auto"
    candidates = select(doi, title, notebook_id, mode)
    print(json.dumps(candidates, indent=2, ensure_ascii=False))
