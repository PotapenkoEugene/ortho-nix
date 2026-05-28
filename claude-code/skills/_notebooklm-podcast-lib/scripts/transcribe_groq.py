"""Transcribe audio via Groq Whisper API with word-level timestamps."""

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


GROQ_API_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
MODEL = "whisper-large-v3-turbo"


def _load_api_key() -> str:
    key = os.environ.get("GROQ_API_KEY")
    if key:
        return key
    secrets = Path.home() / ".secrets" / "env"
    if secrets.exists():
        for line in secrets.read_text().splitlines():
            m = re.match(r'export\s+GROQ_API_KEY=["\']?([^"\']+)["\']?', line)
            if m:
                return m.group(1).strip()
    raise RuntimeError(
        "GROQ_API_KEY not found. Set it in ~/.secrets/env or as environment variable."
    )


def _segments_to_srt(segments: list[dict]) -> str:
    """Convert Groq transcript segments to SRT format."""
    def fmt_time(t: float) -> str:
        h = int(t // 3600)
        m = int((t % 3600) // 60)
        s = int(t % 60)
        ms = int((t - int(t)) * 1000)
        return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

    lines = []
    for i, seg in enumerate(segments, 1):
        start = seg.get("start", 0)
        end = seg.get("end", start + 1)
        text = seg.get("text", "").strip()
        lines.append(f"{i}\n{fmt_time(start)} --> {fmt_time(end)}\n{text}\n")
    return "\n".join(lines)


def transcribe(audio_path: Path, language: str = "ru") -> dict:
    """
    Transcribe audio file via Groq Whisper.

    Returns full verbose_json response dict with:
        - segments[]: {id, start, end, text, ...}
        - words[]: {word, start, end} (word-level timestamps)

    Also writes:
        - {audio_path.stem}_transcript.json
        - {audio_path.stem}_transcript.srt
    in the same directory as audio_path.
    """
    api_key = _load_api_key()
    audio_path = Path(audio_path)

    # Convert to 64kbps MP3 mono 16kHz — keeps size under Groq's 25MB limit
    # (FLAC lossless exceeds 25MB for 35+ min podcasts)
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tf:
        compressed_path = tf.name

    subprocess.run(
        ["ffmpeg", "-y", "-i", str(audio_path),
         "-ar", "16000", "-ac", "1", "-b:a", "64k", compressed_path],
        capture_output=True, check=True,
    )

    compressed_mb = Path(compressed_path).stat().st_size / 1024 / 1024
    if compressed_mb > 24:
        # Still too large (60+ min podcast) — re-encode at 32kbps
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(audio_path),
             "-ar", "16000", "-ac", "1", "-b:a", "32k", compressed_path],
            capture_output=True, check=True,
        )

    try:
        result = subprocess.run(
            [
                "curl", "-s",
                "-X", "POST", GROQ_API_URL,
                "-H", f"Authorization: Bearer {api_key}",
                "-F", f"file=@{compressed_path}",
                "-F", f"model={MODEL}",
                "-F", f"language={language}",
                "-F", "response_format=verbose_json",
                "-F", "timestamp_granularities[]=segment",
                "-F", "timestamp_granularities[]=word",
            ],
            capture_output=True, text=True, timeout=600,
        )
    finally:
        Path(compressed_path).unlink(missing_ok=True)

    if result.returncode != 0:
        raise RuntimeError(f"Groq API call failed: {result.stderr}")

    data = json.loads(result.stdout)
    if "error" in data:
        raise RuntimeError(f"Groq API error: {data['error']}")

    # Write JSON
    json_path = audio_path.parent / "transcript.json"
    json_path.write_text(json.dumps(data, ensure_ascii=False, indent=2))

    # Write SRT
    srt_path = audio_path.parent / "transcript.srt"
    srt_path.write_text(_segments_to_srt(data.get("segments", [])), encoding="utf-8")

    print(f"  Transcript saved: {json_path}")
    print(f"  SRT saved: {srt_path}")
    return data


if __name__ == "__main__":
    audio = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if not audio or not audio.exists():
        print("Usage: transcribe_groq.py <audio.mp3>", file=sys.stderr)
        sys.exit(1)
    result = transcribe(audio)
    print(f"Duration: {result.get('duration', '?'):.1f}s")
    print(f"Segments: {len(result.get('segments', []))}")
    print(f"Words: {len(result.get('words', []))}")
