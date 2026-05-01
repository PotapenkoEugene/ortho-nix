"""Render Excalidraw JSON to PNG using Playwright + headless Chromium.

Usage:
    python3 ~/.claude/skills/excalidraw-diagram/references/render_excalidraw.py <path-to-file.excalidraw> [--output path.png]

First-time setup (if Chromium not found):
    python3 -m playwright install chromium

The excalidraw JS bundle is built on first use and cached at
~/.cache/excalidraw-diagram/excalidraw-bundle.js (takes ~15s; requires pnpm).
"""

from __future__ import annotations

import argparse
import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

BUNDLE_CACHE = Path.home() / ".cache/excalidraw-diagram/excalidraw-bundle.js"
REFERENCES_DIR = Path(__file__).parent


def validate_excalidraw(data: dict) -> list[str]:
    errors: list[str] = []
    if data.get("type") != "excalidraw":
        errors.append(f"Expected type 'excalidraw', got '{data.get('type')}'")
    if "elements" not in data:
        errors.append("Missing 'elements' array")
    elif not isinstance(data["elements"], list):
        errors.append("'elements' must be an array")
    elif len(data["elements"]) == 0:
        errors.append("'elements' array is empty — nothing to render")
    return errors


def compute_bounding_box(elements: list[dict]) -> tuple[float, float, float, float]:
    min_x, min_y = float("inf"), float("inf")
    max_x, max_y = float("-inf"), float("-inf")
    for el in elements:
        if el.get("isDeleted"):
            continue
        x, y = el.get("x", 0), el.get("y", 0)
        w, h = el.get("width", 0), el.get("height", 0)
        if el.get("type") in ("arrow", "line") and "points" in el:
            for px, py in el["points"]:
                min_x, min_y = min(min_x, x + px), min(min_y, y + py)
                max_x, max_y = max(max_x, x + px), max(max_y, y + py)
        else:
            min_x, min_y = min(min_x, x), min(min_y, y)
            max_x, max_y = max(max_x, x + abs(w)), max(max_y, y + abs(h))
    if min_x == float("inf"):
        return (0, 0, 800, 600)
    return (min_x, min_y, max_x, max_y)


def ensure_bundle() -> Path:
    """Build the excalidraw IIFE bundle if not cached. Returns bundle path."""
    if BUNDLE_CACHE.exists():
        return BUNDLE_CACHE

    print("Building excalidraw bundle for first-time use (~15 seconds)...", file=sys.stderr)
    BUNDLE_CACHE.parent.mkdir(parents=True, exist_ok=True)

    build_dir = tempfile.mkdtemp(prefix="excal-build-")
    try:
        pkg = Path(build_dir) / "package.json"
        entry = Path(build_dir) / "entry.js"
        pkg.write_text('{"name":"build","version":"1.0.0","private":true}')
        entry.write_text('export { exportToSvg } from "@excalidraw/excalidraw";\n')

        pnpm = shutil.which("pnpm")
        if not pnpm:
            print("ERROR: pnpm not found in PATH. Install it or run home-manager switch.", file=sys.stderr)
            sys.exit(1)

        subprocess.run(
            [pnpm, "add", "@excalidraw/excalidraw", "esbuild"],
            cwd=build_dir, check=True, capture_output=True,
        )

        esbuild = Path(build_dir) / "node_modules/.bin/esbuild"
        out = Path(build_dir) / "excalidraw-bundle.js"
        subprocess.run(
            [str(esbuild), "entry.js",
             "--bundle", "--format=iife", "--global-name=ExcalidrawLib",
             "--platform=browser", "--minify", f"--outfile={out}"],
            cwd=build_dir, check=True, capture_output=True,
        )

        shutil.copy(out, BUNDLE_CACHE)
        print(f"Bundle built and cached at {BUNDLE_CACHE}", file=sys.stderr)
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Bundle build failed: {e.stderr.decode()[:500]}", file=sys.stderr)
        sys.exit(1)
    finally:
        shutil.rmtree(build_dir, ignore_errors=True)

    return BUNDLE_CACHE


def render(
    excalidraw_path: Path,
    output_path: Path | None = None,
    scale: int = 2,
    max_width: int = 1920,
) -> Path:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("ERROR: playwright not installed.", file=sys.stderr)
        print("Run: python3 -m playwright install chromium", file=sys.stderr)
        sys.exit(1)

    raw = excalidraw_path.read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {excalidraw_path}: {e}", file=sys.stderr)
        sys.exit(1)

    errors = validate_excalidraw(data)
    if errors:
        print("ERROR: Invalid Excalidraw file:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)

    elements = [e for e in data["elements"] if not e.get("isDeleted")]
    min_x, min_y, max_x, max_y = compute_bounding_box(elements)
    padding = 80
    vp_width = min(int(max_x - min_x + padding * 2), max_width)
    vp_height = max(int(max_y - min_y + padding * 2), 600)

    if output_path is None:
        output_path = excalidraw_path.with_suffix(".png")

    bundle_path = ensure_bundle()

    # Serve template + bundle from a temp dir over localhost (avoids file:// CORS issues)
    serve_dir = tempfile.mkdtemp(prefix="excal-serve-")
    try:
        shutil.copy(REFERENCES_DIR / "render_template.html", serve_dir)
        shutil.copy(bundle_path, Path(serve_dir) / "excalidraw-bundle.js")

        class QuietHandler(http.server.SimpleHTTPRequestHandler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=serve_dir, **kwargs)
            def log_message(self, *a): pass

        httpd = http.server.HTTPServer(("localhost", 0), QuietHandler)
        port = httpd.server_address[1]
        thread = threading.Thread(target=httpd.serve_forever)
        thread.daemon = True
        thread.start()

        import time
        time.sleep(0.2)  # Let server become ready

        try:
            _do_render(data, f"http://localhost:{port}/render_template.html",
                       output_path, vp_width, vp_height, scale, sync_playwright)
        finally:
            httpd.shutdown()
    finally:
        shutil.rmtree(serve_dir, ignore_errors=True)

    return output_path


def _do_render(data, template_url, output_path, vp_width, vp_height, scale, sync_playwright):
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch(headless=True)
        except Exception as e:
            if "Executable doesn't exist" in str(e) or "browserType.launch" in str(e):
                print("ERROR: Chromium not installed for Playwright.", file=sys.stderr)
                print("Run: python3 -m playwright install chromium", file=sys.stderr)
                sys.exit(1)
            raise

        page = browser.new_page(
            viewport={"width": vp_width, "height": vp_height},
            device_scale_factor=scale,
        )
        page.goto(template_url, wait_until="networkidle")
        page.wait_for_function("window.__moduleReady === true", timeout=15000)

        json_str = json.dumps(data)
        result = page.evaluate(f"window.renderDiagram({json_str})")

        if not result or not result.get("success"):
            error_msg = result.get("error", "Unknown render error") if result else "renderDiagram returned null"
            print(f"ERROR: Render failed: {error_msg}", file=sys.stderr)
            browser.close()
            sys.exit(1)

        page.wait_for_function("window.__renderComplete === true", timeout=15000)

        svg_el = page.query_selector("#root svg")
        if svg_el is None:
            print("ERROR: No SVG element found after render.", file=sys.stderr)
            browser.close()
            sys.exit(1)

        svg_el.screenshot(path=str(output_path))
        browser.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Render Excalidraw JSON to PNG")
    parser.add_argument("input", type=Path, help="Path to .excalidraw JSON file")
    parser.add_argument("--output", "-o", type=Path, default=None, help="Output PNG path")
    parser.add_argument("--scale", "-s", type=int, default=2, help="Device scale factor (default: 2)")
    parser.add_argument("--width", "-w", type=int, default=1920, help="Max viewport width (default: 1920)")
    args = parser.parse_args()

    if not args.input.exists():
        print(f"ERROR: File not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    png_path = render(args.input, args.output, args.scale, args.width)
    print(str(png_path))


if __name__ == "__main__":
    main()
