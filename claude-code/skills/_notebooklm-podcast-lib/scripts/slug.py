"""Generate filesystem-safe episode slug from paper metadata."""

import re
import unicodedata


def _ascii_slug(text: str) -> str:
    text = unicodedata.normalize("NFD", text)
    text = text.encode("ascii", "ignore").decode()
    text = re.sub(r"[^\w\s-]", "", text.lower())
    text = re.sub(r"[\s_-]+", "-", text.strip())
    return text


def make_slug(first_author_surname: str, year: int | str, title: str) -> str:
    """Return slug like 'smith_2024_wild-barley-population' (3 title words max)."""
    author = _ascii_slug(first_author_surname)[:20].strip("-")
    yr = str(year)[:4]
    # Take first 3 meaningful words from title (skip stopwords)
    stopwords = {
        "a", "an", "the", "of", "in", "on", "at", "to", "for", "and",
        "or", "but", "with", "from", "by", "is", "are", "was", "were",
    }
    words = [w for w in re.split(r"\W+", title.lower()) if w and w not in stopwords]
    title_part = "-".join(words[:3])
    title_part = _ascii_slug(title_part)[:40].strip("-")
    return f"{author}_{yr}_{title_part}"
