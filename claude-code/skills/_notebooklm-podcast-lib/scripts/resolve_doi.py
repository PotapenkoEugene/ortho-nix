"""Resolve DOI to open-access PDF path + metadata. Hard-fail on paywall."""

import json
import re
import sys
import time
from pathlib import Path

import requests

UNPAYWALL_EMAIL = "selfisheugenes@gmail.com"
HEADERS = {"User-Agent": f"notebooklm-popsci/1.0 (mailto:{UNPAYWALL_EMAIL})"}
TIMEOUT = 30
SCIHUB_MIRRORS = ["https://sci-hub.se", "https://sci-hub.st", "https://sci-hub.ru", "https://sci-hub.ee"]


class PaywallError(Exception):
    """Raised when paper exists but no OA copy is available."""


class DOINotFoundError(Exception):
    """Raised when DOI cannot be resolved at all."""


class OAURLOnlyError(Exception):
    """Paper is OA but PDF download is blocked; url attribute has the best OA URL."""
    def __init__(self, message: str, url: str):
        super().__init__(message)
        self.url = url


def _crossref_meta(doi: str) -> dict:
    """Fetch title/authors/year/journal from CrossRef."""
    url = f"https://api.crossref.org/works/{doi}"
    r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
    if r.status_code != 200:
        return {}
    w = r.json().get("message", {})
    authors = []
    for a in w.get("author", []):
        name = a.get("family", "") or a.get("name", "")
        if name:
            authors.append(name)
    title_list = w.get("title", [])
    title = title_list[0] if title_list else ""
    year = None
    for date_field in ("published", "published-print", "published-online", "issued"):
        dp = w.get(date_field, {}).get("date-parts", [[]])
        if dp and dp[0]:
            year = dp[0][0]
            break
    journal_list = w.get("container-title", [])
    journal = journal_list[0] if journal_list else ""
    return {
        "doi": doi,
        "title": title,
        "authors": authors,
        "year": year,
        "journal": journal,
    }


def _download_pdf(url: str, dest: Path) -> bool:
    """Download PDF from URL to dest. Returns True on success."""
    try:
        r = requests.get(url, stream=True, allow_redirects=True,
                         timeout=TIMEOUT, headers=HEADERS)
        ct = r.headers.get("Content-Type", "")
        if r.status_code != 200 or "pdf" not in ct:
            return False
        dest.parent.mkdir(parents=True, exist_ok=True)
        with open(dest, "wb") as f:
            for chunk in r.iter_content(chunk_size=65536):
                f.write(chunk)
        return dest.stat().st_size > 10_000
    except Exception:
        return False


def _try_unpaywall(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try Unpaywall. Returns (success, source_info)."""
    url = f"https://api.unpaywall.org/v2/{doi}?email={UNPAYWALL_EMAIL}"
    try:
        r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
        if r.status_code != 200:
            return False, {}
        data = r.json()
        if not data.get("is_oa"):
            raise PaywallError(
                f"Paper '{data.get('title', doi)}' is not open access (Unpaywall)."
            )
        loc = data.get("best_oa_location") or {}
        pdf_url = loc.get("url_for_pdf") or loc.get("url")
        if not pdf_url:
            # Try alternate locations
            for alt in data.get("oa_locations", []):
                if alt.get("url_for_pdf"):
                    pdf_url = alt["url_for_pdf"]
                    break
        if not pdf_url:
            return False, {"source": "unpaywall", "oa": True, "pdf_url": None}
        if _download_pdf(pdf_url, dest):
            return True, {
                "source": "unpaywall",
                "pdf_url": pdf_url,
                "version": loc.get("version"),
                "license": loc.get("license"),
                "host_type": loc.get("host_type"),
            }
        return False, {}
    except PaywallError:
        raise
    except Exception:
        return False, {}


def _try_biorxiv(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try bioRxiv API (works for biorxiv/medrxiv preprints)."""
    for server in ("biorxiv", "medrxiv"):
        try:
            url = f"https://api.biorxiv.org/details/{server}/{doi}"
            r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
            if r.status_code != 200:
                continue
            data = r.json()
            collection = data.get("collection", [])
            if not collection:
                continue
            latest = sorted(collection, key=lambda x: x.get("version", "0"))[-1]
            pdf_url = f"https://www.biorxiv.org/content/{doi}v{latest.get('version','1')}.full.pdf"
            if _download_pdf(pdf_url, dest):
                return True, {"source": server, "pdf_url": pdf_url}
        except Exception:
            continue
    return False, {}


def _try_arxiv(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try arXiv if DOI is 10.48550/arXiv.*"""
    m = re.match(r"10\.48550/arXiv\.(\d{4}\.\d{4,5})", doi, re.I)
    if not m:
        return False, {}
    arxiv_id = m.group(1)
    pdf_url = f"https://arxiv.org/pdf/{arxiv_id}.pdf"
    if _download_pdf(pdf_url, dest):
        return True, {"source": "arxiv", "pdf_url": pdf_url}
    return False, {}


def _try_crossref_links(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try CrossRef link[] entries for direct PDF."""
    try:
        r = requests.get(f"https://api.crossref.org/works/{doi}",
                         headers=HEADERS, timeout=TIMEOUT)
        if r.status_code != 200:
            return False, {}
        links = r.json().get("message", {}).get("link", [])
        for link in links:
            if "pdf" in link.get("content-type", "").lower():
                if _download_pdf(link["URL"], dest):
                    return True, {"source": "crossref_link", "pdf_url": link["URL"]}
    except Exception:
        pass
    return False, {}


def _try_europepmc(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try Europe PMC fullTextUrlList for a direct PDF."""
    try:
        r = requests.get(
            "https://www.ebi.ac.uk/europepmc/webservices/rest/search",
            params={"query": f"DOI:{doi}", "format": "json", "resultType": "core"},
            headers=HEADERS, timeout=TIMEOUT,
        )
        if r.status_code != 200:
            return False, {}
        results = r.json().get("resultList", {}).get("result", [])
        if not results:
            return False, {}
        for ft in results[0].get("fullTextUrlList", {}).get("fullTextUrl", []):
            if ft.get("documentStyle") == "pdf" and ft.get("availability") in ("Open access", "Free"):
                pdf_url = ft.get("url")
                if pdf_url and _download_pdf(pdf_url, dest):
                    return True, {"source": "europepmc", "pdf_url": pdf_url}
    except Exception:
        pass
    return False, {}


def _try_openalex(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try OpenAlex for OA PDF URLs (more mirrors than Unpaywall)."""
    try:
        r = requests.get(
            f"https://api.openalex.org/works/doi:{doi}",
            headers=HEADERS, timeout=TIMEOUT,
        )
        if r.status_code != 200:
            return False, {}
        data = r.json()
        candidates: list[str] = []
        oa_url = data.get("open_access", {}).get("oa_url")
        if oa_url:
            candidates.append(oa_url)
        for loc in data.get("locations", []):
            pdf_url = loc.get("pdf_url")
            if pdf_url and pdf_url not in candidates:
                candidates.append(pdf_url)
        for pdf_url in candidates:
            if _download_pdf(pdf_url, dest):
                return True, {"source": "openalex", "pdf_url": pdf_url}
    except Exception:
        pass
    return False, {}


def _try_playwright(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try fetching PDF via headless Playwright browser (handles JS-gated downloads)."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return False, {}

    # Re-query Unpaywall for OA PDF URLs — they may work with a real browser
    candidate_urls: list[str] = []
    try:
        r = requests.get(
            f"https://api.unpaywall.org/v2/{doi}?email={UNPAYWALL_EMAIL}",
            headers=HEADERS, timeout=TIMEOUT,
        )
        if r.status_code == 200:
            for loc in r.json().get("oa_locations", []):
                url_pdf = loc.get("url_for_pdf")
                if url_pdf and url_pdf not in candidate_urls:
                    candidate_urls.append(url_pdf)
    except Exception:
        pass
    doi_url = f"https://doi.org/{doi}"
    if doi_url not in candidate_urls:
        candidate_urls.append(doi_url)

    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            ctx = browser.new_context(
                user_agent=(
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/131.0.0.0 Safari/537.36"
                ),
                accept_downloads=True,
            )
            for url in candidate_urls:
                page = ctx.new_page()
                try:
                    resp = page.goto(url, wait_until="domcontentloaded", timeout=20000)
                    if resp and "pdf" in (resp.headers.get("content-type", "")).lower():
                        body = resp.body()
                        if len(body) > 10_000:
                            dest.write_bytes(body)
                            browser.close()
                            return True, {"source": "playwright", "pdf_url": url}
                except Exception:
                    pass
                finally:
                    page.close()
            browser.close()
    except Exception:
        pass
    return False, {}


def _try_scihub(doi: str, dest: Path) -> tuple[bool, dict]:
    """Try Sci-Hub mirrors for paywalled papers."""
    for mirror in SCIHUB_MIRRORS:
        try:
            r = requests.get(
                f"{mirror}/{doi}", headers=HEADERS, timeout=TIMEOUT, allow_redirects=True,
            )
            if r.status_code != 200:
                continue
            m = re.search(
                r'(?:embed|iframe)[^>]+src\s*=\s*["\']([^"\']+\.pdf[^"\']*)',
                r.text, re.I,
            )
            if not m:
                continue
            pdf_url = m.group(1)
            if pdf_url.startswith("//"):
                pdf_url = "https:" + pdf_url
            elif pdf_url.startswith("/"):
                pdf_url = mirror + pdf_url
            if _download_pdf(pdf_url, dest):
                return True, {"source": "scihub", "mirror": mirror, "pdf_url": pdf_url}
        except Exception:
            continue
    return False, {}


def _extract_doi_from_pdf(pdf_path: Path) -> str | None:
    """Extract DOI from first 2 pages of PDF text using pdftotext."""
    try:
        import subprocess
        r = subprocess.run(
            ["pdftotext", "-l", "2", str(pdf_path), "-"],
            capture_output=True, text=True, timeout=15,
        )
        text = r.stdout
        m = re.search(r"\b(10\.\d{4,9}/\S+)", text)
        if m:
            doi = m.group(1).rstrip(".,;)\"'")
            return doi
    except Exception:
        pass
    return None


def resolve(doi_or_path: str, dest: Path) -> dict:
    """
    Resolve a DOI or PDF path to a local PDF + metadata dict.

    Args:
        doi_or_path: DOI string (e.g. "10.7554/eLife.93210") or local PDF path.
        dest: Where to save the PDF (e.g. episode_dir/pdfs/primary.pdf).

    Returns:
        metadata dict: {doi, title, authors, year, journal, pdf_path, source}

    Raises:
        PaywallError: paper exists but no OA copy available.
        DOINotFoundError: DOI cannot be resolved.
        FileNotFoundError: local path doesn't exist.
    """
    # Case 1: local PDF
    p = Path(doi_or_path)
    if p.exists() and p.suffix.lower() == ".pdf":
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest != p:
            import shutil
            shutil.copy2(p, dest)
        # Try to extract DOI from PDF text (first 2 pages) → CrossRef metadata
        extracted_doi = _extract_doi_from_pdf(dest)
        if extracted_doi:
            try:
                meta = _crossref_meta(extracted_doi)
                if meta.get("title"):
                    meta.update({"pdf_path": str(dest), "source": "local", "doi": extracted_doi})
                    return meta
            except Exception:
                pass
        return {
            "doi": None,
            "title": p.stem,
            "authors": [],
            "year": None,
            "journal": None,
            "pdf_path": str(dest),
            "source": "local",
        }

    # Case 2: DOI
    doi = doi_or_path.strip()
    # Normalise: strip URL prefix
    doi = re.sub(r"^https?://(dx\.)?doi\.org/", "", doi)

    dest.parent.mkdir(parents=True, exist_ok=True)
    meta = _crossref_meta(doi)

    # Resolution chain
    for attempt_fn in [
        _try_unpaywall,
        _try_arxiv,
        _try_biorxiv,
        _try_europepmc,
        _try_openalex,
        _try_crossref_links,
        _try_playwright,
        _try_scihub,
    ]:
        try:
            ok, source_info = attempt_fn(doi, dest)
        except PaywallError:
            raise
        if ok:
            meta.update({"pdf_path": str(dest), **source_info})
            return meta
        time.sleep(0.3)

    # Check if paper is OA but PDF is just inaccessible to scripts (e.g. PMC)
    url = f"https://api.unpaywall.org/v2/{doi}?email={UNPAYWALL_EMAIL}"
    try:
        r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
        if r.status_code == 200:
            data = r.json()
            if data.get("is_oa"):
                # Find best URL (prefer direct PDF, fall back to landing page)
                best_url = None
                for loc in data.get("oa_locations", []):
                    if loc.get("url_for_pdf"):
                        best_url = loc["url_for_pdf"]
                        break
                if not best_url:
                    best_url = (data.get("best_oa_location") or {}).get("url")
                if not best_url:
                    best_url = f"https://doi.org/{doi}"
                raise OAURLOnlyError(
                    f"Paper is OA but PDF download is blocked (e.g. PMC requires browser). "
                    f"Will use URL source: {best_url}",
                    url=best_url,
                )
    except OAURLOnlyError:
        raise
    except Exception:
        pass

    raise DOINotFoundError(
        f"Could not retrieve PDF for DOI {doi}. "
        "Check open-access availability or provide the PDF path directly."
    )


if __name__ == "__main__":
    doi = sys.argv[1] if len(sys.argv) > 1 else "10.7554/eLife.93210"
    dest = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("/tmp/test_resolve.pdf")
    try:
        meta = resolve(doi, dest)
        print(json.dumps(meta, indent=2, ensure_ascii=False))
    except (PaywallError, DOINotFoundError) as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
