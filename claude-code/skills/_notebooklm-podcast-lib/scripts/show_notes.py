"""Build show-notes.md and derive YouTube chapters from transcript."""

import json
import re
from pathlib import Path


def _fmt_ts(seconds: float) -> str:
    """Float seconds → MM:SS YouTube chapter format."""
    m = int(seconds // 60)
    s = int(seconds % 60)
    return f"{m:02d}:{s:02d}"


def _derive_chapters(segments: list[dict], n_chapters: int = 5) -> list[tuple[float, str]]:
    """
    Split transcript segments into n_chapters by equal-duration buckets.
    Returns list of (start_sec, chapter_title_ru).
    Chapter titles are approximated from first sentence of each segment group.
    """
    if not segments:
        return []
    total = segments[-1].get("end", 0)
    bucket = total / n_chapters
    chapters = []
    bucket_start = 0.0
    current_bucket_segs = []
    chapter_idx = 0

    chapter_labels_ru = [
        "Вводная часть",
        "Контекст и цели",
        "Методы",
        "Результаты",
        "Ограничения и выводы",
    ]

    for seg in segments:
        seg_start = seg.get("start", 0)
        if seg_start >= bucket_start + bucket and chapter_idx < n_chapters - 1:
            label = chapter_labels_ru[chapter_idx] if chapter_idx < len(chapter_labels_ru) else f"Часть {chapter_idx + 1}"
            chapters.append((bucket_start, label))
            bucket_start += bucket
            chapter_idx += 1
        current_bucket_segs.append(seg)

    # Last chapter
    if current_bucket_segs:
        label = chapter_labels_ru[chapter_idx] if chapter_idx < len(chapter_labels_ru) else f"Часть {chapter_idx + 1}"
        chapters.append((bucket_start, label))

    return chapters


def build(
    episode_dir: Path,
    primary_meta: dict,
    companions: list[dict],
    transcript_json: dict,
    notebook_summary: str = "",
    ru_title: str = "",
) -> Path:
    """
    Write show-notes.md to episode_dir. Returns the path.

    Args:
        episode_dir: episode bundle directory
        primary_meta: {doi, title, authors, year, journal, source}
        companions: list of {doi, title, authors, year, type, rationale}
        transcript_json: Groq verbose_json
        notebook_summary: 2-3 sentence summary from NotebookLM chat-mode
        ru_title: Russian episode title (if known)
    """
    segments = transcript_json.get("segments", [])
    duration_sec = transcript_json.get("duration", 0)
    duration_str = _fmt_ts(duration_sec)
    chapters = _derive_chapters(segments)

    authors = primary_meta.get("authors", [])
    author_str = authors[0] if authors else "Unknown"
    if len(authors) > 1:
        author_str += f" et al."

    doi = primary_meta.get("doi", "")
    doi_link = f"https://doi.org/{doi}" if doi else ""
    title_en = primary_meta.get("title", "")
    year = primary_meta.get("year", "")
    journal = primary_meta.get("journal", "")

    episode_title = ru_title or f"[RU title: {title_en[:80]}]"

    lines = []
    lines.append(f"# {episode_title}")
    lines.append("")
    lines.append(f"**Длительность:** {duration_str}  ")
    if doi:
        lines.append(f"**DOI:** [{doi}]({doi_link})  ")
    if author_str and year:
        lines.append(f"**Авторы:** {author_str} ({year}), {journal}  ")
    lines.append("")

    if notebook_summary:
        lines.append("## О чём этот выпуск")
        lines.append("")
        lines.append(notebook_summary)
        lines.append("")

    # Chapters block
    if chapters:
        lines.append("## Содержание")
        lines.append("")
        for start_sec, label in chapters:
            lines.append(f"{_fmt_ts(start_sec)} {label}")
        lines.append("")

    # Sources
    lines.append("## Источники")
    lines.append("")
    lines.append(f"**Основная статья:**")
    lines.append(f"- {title_en}")
    if author_str:
        lines.append(f"  {author_str} ({year}). *{journal}*")
    if doi_link:
        lines.append(f"  {doi_link}")
    lines.append("")

    if companions:
        lines.append("**Дополнительные источники:**")
        for i, c in enumerate(companions, 1):
            c_doi = c.get("doi", "")
            c_title = c.get("title", "")
            c_authors = c.get("authors", [])
            c_year = c.get("year", "")
            c_type = c.get("type", "")
            c_rationale = c.get("rationale", "")
            c_doi_link = f"https://doi.org/{c_doi}" if c_doi else ""
            c_author_str = c_authors[0] + " et al." if len(c_authors) > 1 else (c_authors[0] if c_authors else "")
            label = f"{'Обзор' if c_type == 'review' else 'Статья'}"
            lines.append(f"{i}. [{label}] {c_title}")
            if c_author_str:
                lines.append(f"   {c_author_str} ({c_year})")
            if c_doi_link:
                lines.append(f"   {c_doi_link}")
            if c_rationale:
                lines.append(f"   *Почему: {c_rationale}*")
        lines.append("")

    lines.append("---")
    lines.append("*Подкаст создан автоматически через NotebookLM + Groq Whisper.*")
    lines.append("*Перед публикацией: пройдите QA-чеклист в meta.json.*")

    out = episode_dir / "show-notes.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"  Show-notes: {out}")
    return out
