"""
Load and validate a NotebookLM pipeline profile.

A profile is a YAML file under _notebooklm-podcast-lib/profiles/ that bundles
all NotebookLM levers: format, length, configure settings, prompt templates,
style-guide source, and knowledge-extraction defaults.
"""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "pyyaml"], check=True)
    import yaml

PROFILES_DIR = Path(__file__).parent.parent / "profiles"
PROMPTS_DIR = Path(__file__).parent.parent / "prompts"

VALID_FORMATS = {"deep-dive", "brief", "critique", "debate"}
VALID_LENGTHS = {"short", "default", "long"}
VALID_MODES = {"default", "learning-guide", "concise", "detailed"}
VALID_RESPONSE_LENGTHS = {"default", "longer", "shorter"}
VALID_KNOWLEDGE_TYPES = {
    "briefing", "study-guide", "faq", "timeline",
    "glossary", "concept-inventory", "controversies",
}

RUSSIAN_LENGTH_CLAMP = "default"
RUSSIAN_LANGUAGES = {"ru"}


class ProfileError(Exception):
    pass


def load(name: str) -> dict:
    """Load profile by name. Searches profiles/ dir. Returns validated dict."""
    path = PROFILES_DIR / f"{name}.yaml"
    if not path.exists():
        available = [p.stem for p in PROFILES_DIR.glob("*.yaml")]
        raise ProfileError(
            f"Profile '{name}' not found. Available: {', '.join(available) or 'none'}"
        )
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    return _validate(raw, name)


def _validate(raw: dict, name: str) -> dict:
    fmt = raw.get("format", "deep-dive")
    if fmt not in VALID_FORMATS:
        raise ProfileError(f"Profile '{name}': invalid format '{fmt}'. Must be one of {VALID_FORMATS}")

    lang = raw.get("language", "en")
    length = raw.get("length", "default")
    if lang in RUSSIAN_LANGUAGES and length != RUSSIAN_LENGTH_CLAMP:
        print(
            f"  [profile] Warning: '{name}' sets length='{length}' for language='{lang}'. "
            f"NotebookLM ignores this for non-English. Clamping to '{RUSSIAN_LENGTH_CLAMP}'."
        )
        raw["length"] = RUSSIAN_LENGTH_CLAMP

    configure = raw.get("configure", {})
    mode = configure.get("mode", "default")
    if mode not in VALID_MODES:
        raise ProfileError(f"Profile '{name}': invalid configure.mode '{mode}'")
    resp_len = configure.get("response_length", "default")
    if resp_len not in VALID_RESPONSE_LENGTHS:
        raise ProfileError(f"Profile '{name}': invalid configure.response_length '{resp_len}'")

    for kt in raw.get("knowledge_extraction_defaults", []):
        if kt not in VALID_KNOWLEDGE_TYPES:
            raise ProfileError(f"Profile '{name}': unknown knowledge type '{kt}'")

    return raw


def resolve_customize_prompt_path(profile: dict) -> Path | None:
    """Return absolute path to the customize prompt template, or None."""
    rel = profile.get("customize_prompt_path")
    if not rel:
        return None
    path = PROMPTS_DIR / rel
    if not path.exists():
        raise ProfileError(f"customize_prompt_path not found: {path}")
    return path


def resolve_style_guide_path(profile: dict) -> Path | None:
    """Return absolute path to style-guide source file, or None."""
    rel = profile.get("style_guide_source")
    if not rel:
        return None
    path = PROMPTS_DIR / rel
    if not path.exists():
        raise ProfileError(f"style_guide_source not found: {path}")
    return path


def resolve_knowledge_prompt_path(knowledge_type: str) -> Path:
    """Return absolute path to a knowledge extraction prompt template."""
    if knowledge_type not in VALID_KNOWLEDGE_TYPES:
        raise ProfileError(f"Unknown knowledge type '{knowledge_type}'. Valid: {VALID_KNOWLEDGE_TYPES}")
    path = PROMPTS_DIR / "knowledge" / f"{knowledge_type}.md"
    if not path.exists():
        raise ProfileError(f"Knowledge prompt not found: {path}")
    return path


def print_profile(profile: dict):
    """Print profile summary for inspection."""
    name = profile.get("name", "?")
    print(f"Profile: {name}")
    print(f"  language : {profile.get('language', 'en')}")
    print(f"  format   : {profile.get('format', 'deep-dive')}")
    print(f"  length   : {profile.get('length', 'default')}")
    cfg = profile.get("configure", {})
    print(f"  configure:")
    print(f"    mode            : {cfg.get('mode', 'default')}")
    print(f"    response_length : {cfg.get('response_length', 'default')}")
    persona = cfg.get("persona", "").strip()
    print(f"    persona         : {persona[:80]}{'...' if len(persona) > 80 else ''}")
    prompt_path = resolve_customize_prompt_path(profile)
    print(f"  customize_prompt  : {prompt_path or '(none)'}")
    sg = resolve_style_guide_path(profile)
    print(f"  style_guide       : {sg or '(none)'}")
    kd = profile.get("knowledge_extraction_defaults", [])
    print(f"  knowledge_defaults: {', '.join(kd) or '(none)'}")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Inspect a pipeline profile.")
    parser.add_argument("name", help="Profile name (e.g. popsci-ru)")
    args = parser.parse_args()
    try:
        p = load(args.name)
        print_profile(p)
    except ProfileError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
