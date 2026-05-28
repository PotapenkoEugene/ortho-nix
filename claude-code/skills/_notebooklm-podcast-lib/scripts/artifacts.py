"""
Generate non-audio NotebookLM artifacts: mind-map, flashcards, quiz.

Usage (from pipeline.py or standalone):
    from artifacts import generate_artifacts
    generate_artifacts(notebook_id, episode_dir, types=["mind-map", "flashcards", "quiz"])
"""

import json
import subprocess
import sys
from pathlib import Path

ARTIFACT_TYPES = {
    "mind-map": {
        "cli_name": "mind-map",
        "output_file": "mindmap.json",
        "download_flag": "mind-map",
        "description": "Concept map",
    },
    "flashcards": {
        "cli_name": "flashcards",
        "output_file": "flashcards.md",
        "download_flag": "flashcards",
        "description": "Flashcard set",
    },
    "quiz": {
        "cli_name": "quiz",
        "output_file": "quiz.md",
        "download_flag": "quiz",
        "description": "Quiz questions",
    },
}

TIMEOUT_GENERATE = 900
TIMEOUT_WAIT = 60
TIMEOUT_DOWNLOAD = 120


def _run(cmd: list[str], desc: str, capture: bool = True, timeout: int = 60) -> subprocess.CompletedProcess:
    result = subprocess.run(cmd, capture_output=capture, text=True, timeout=timeout)
    if result.returncode != 0:
        stderr = (result.stderr or result.stdout or "").strip()
        raise RuntimeError(f"{desc} failed (exit {result.returncode}): {stderr[:300]}")
    return result


def _get_latest_artifact_id(notebook_id: str, artifact_type_id: str) -> str | None:
    result = subprocess.run(
        ["notebooklm", "artifact", "list", "--json", "-n", notebook_id],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        return None
    try:
        artifacts = json.loads(result.stdout).get("artifacts", [])
        matching = [a for a in artifacts if a.get("type_id") == artifact_type_id]
        if not matching:
            return None
        return sorted(matching, key=lambda x: x.get("created_at", ""), reverse=True)[0]["id"]
    except Exception:
        return None


def generate_artifacts(
    notebook_id: str,
    episode_dir: Path,
    types: list[str],
) -> dict[str, Path | None]:
    """
    Generate requested artifact types and download to episode_dir.
    Returns dict of {type: output_path | None}.
    Types can be: "mind-map", "flashcards", "quiz".
    """
    results: dict[str, Path | None] = {}
    unknown = set(types) - set(ARTIFACT_TYPES)
    if unknown:
        print(f"  Warning: unknown artifact types: {unknown}. Skipping.")
        types = [t for t in types if t in ARTIFACT_TYPES]

    if not types:
        return results

    print(f"\nGenerating artifacts: {', '.join(types)}")
    _run(["notebooklm", "use", notebook_id], "notebooklm use", timeout=15)

    for atype in types:
        spec = ARTIFACT_TYPES[atype]
        out_path = episode_dir / spec["output_file"]
        print(f"  Generating {spec['description']} ({atype})...")
        try:
            gen_result = _run(
                ["notebooklm", "generate", spec["cli_name"], "--no-wait", "--json", "-n", notebook_id],
                f"generate {atype}",
                capture=True,
                timeout=30,
            )
            artifact_id = ""
            try:
                data = json.loads(gen_result.stdout)
                artifact_id = data.get("id") or data.get("artifact_id") or ""
            except Exception:
                pass
            if not artifact_id:
                artifact_id = _get_latest_artifact_id(notebook_id, atype) or ""

            if artifact_id:
                print(f"    Waiting for {atype} (artifact: {artifact_id})...")
                subprocess.run(
                    ["notebooklm", "artifact", "wait", artifact_id,
                     "-n", notebook_id, "--timeout", "600", "--interval", "10"],
                    capture_output=True, text=True, timeout=TIMEOUT_GENERATE,
                )
            else:
                print(f"    Warning: no artifact ID for {atype}, waiting 60s...")
                import time
                time.sleep(60)

            # Download
            print(f"    Downloading {atype}...")
            dl_cmd = ["notebooklm", "download", spec["download_flag"],
                      str(out_path), "--latest", "-n", notebook_id]
            dl_result = subprocess.run(dl_cmd, capture_output=True, text=True, timeout=TIMEOUT_DOWNLOAD)
            if dl_result.returncode != 0 or not out_path.exists():
                print(f"    Warning: download failed for {atype}: {(dl_result.stderr or '').strip()[:200]}")
                results[atype] = None
            else:
                size = out_path.stat().st_size
                print(f"    {atype}: {out_path} ({size} bytes)")
                results[atype] = out_path

        except Exception as e:
            print(f"    Error generating {atype}: {e}")
            results[atype] = None

    return results
