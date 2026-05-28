"""
Apply notebooklm configure to a notebook based on profile settings.

Calls: notebooklm configure -n <id> --persona "..." --mode <m> --response-length <r>
"""

import subprocess
import sys


def configure(notebook_id: str, profile: dict) -> bool:
    """
    Apply configure settings from profile to the notebook.
    Returns True on success, False on failure (non-fatal — pipeline continues).
    """
    cfg = profile.get("configure", {})
    mode = cfg.get("mode", "default")
    response_length = cfg.get("response_length", "default")
    persona = cfg.get("persona", "").strip()

    if not persona and mode == "default" and response_length == "default":
        return True  # nothing to set

    cmd = ["notebooklm", "configure", "-n", notebook_id]
    if mode and mode != "default":
        cmd += ["--mode", mode]
    if response_length and response_length != "default":
        cmd += ["--response-length", response_length]
    if persona:
        cmd += ["--persona", persona]

    print(f"  $ notebooklm configure -n {notebook_id[:8]}... --mode {mode} --response-length {response_length}")
    if persona:
        print(f"    persona: {persona[:80]}{'...' if len(persona) > 80 else ''}")

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        stderr = (result.stderr or result.stdout or "").strip()
        print(f"  Warning: notebooklm configure failed (exit {result.returncode}): {stderr[:200]}")
        print("  Continuing without persona/mode configuration.")
        return False

    print("  Notebook configured.")
    return True
