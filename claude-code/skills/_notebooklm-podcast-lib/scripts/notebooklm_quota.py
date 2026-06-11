"""Check NotebookLM daily audio generation quota (NotebookLM Plus: 20/day)."""

import json
import subprocess
import sys
from datetime import date


FREE_TIER_DAILY_LIMIT = 20


class QuotaExhaustedError(Exception):
    pass


def _audio_count_today() -> int:
    """Count completed audio artifacts created today across all notebooks."""
    today = date.today().isoformat()  # "2026-05-18"
    try:
        # List all notebooks
        result = subprocess.run(
            ["notebooklm", "list", "--json"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            return 0
        notebooks = json.loads(result.stdout).get("notebooks", [])
    except Exception:
        return 0

    count = 0
    for nb in notebooks:
        nb_id = nb.get("id", "")
        try:
            r = subprocess.run(
                ["notebooklm", "artifact", "list", "--json", "-n", nb_id, "--type", "audio"],
                capture_output=True, text=True, timeout=20,
            )
            if r.returncode != 0:
                continue
            data = json.loads(r.stdout)
            for artifact in data.get("artifacts", []):
                created = artifact.get("created_at", "")
                if created.startswith(today) and artifact.get("type_id") == "audio":
                    count += 1
        except Exception:
            continue
    return count


def check(limit: int = FREE_TIER_DAILY_LIMIT) -> int:
    """
    Check quota. Returns count of audio artifacts created today.
    Raises QuotaExhaustedError if count >= limit.
    """
    count = _audio_count_today()
    if count >= limit:
        raise QuotaExhaustedError(
            f"NotebookLM daily quota exhausted: {count}/{limit} audio overviews generated today. "
            "Try again tomorrow (resets at UTC 00:00)."
        )
    return count


if __name__ == "__main__":
    try:
        n = check()
        print(f"Quota OK: {n}/{FREE_TIER_DAILY_LIMIT} used today.")
    except QuotaExhaustedError as e:
        print(f"QUOTA: {e}", file=sys.stderr)
        sys.exit(1)
