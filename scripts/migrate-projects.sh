#!/usr/bin/env bash
# migrate-projects.sh — One-time vault migration: flat projects → subdir layout
#
# Moves:  ~/Orthidian/projects/Foo.md  →  ~/Orthidian/projects/Foo/Foo.md
#         ~/Orthidian/personal/Katusha.md → ~/Orthidian/personal/Katusha/Katusha.md
# Leaves flat: personal/{tasks,payments,english}.md (not project files)
# Deletes: *.md.hl Highlighter artifacts
# Fixes:  [[projects/Foo]] → [[Foo]] in all knowledge notes
#
# Run ONCE in ~/Orthidian (must be a clean vault — commit pending changes first).
# Safe to re-run (idempotent: skips already-migrated paths).
#
# Usage: bash ~/.config/home-manager/scripts/migrate-projects.sh

set -euo pipefail
cd "$HOME/Orthidian"

# ── Guard: must be a git repo ──────────────────────────────────────────────────
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: not a git repo. Run from ~/Orthidian." >&2
  exit 1
fi

# ── Guard: must be clean ───────────────────────────────────────────────────────
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: vault has uncommitted changes. Commit them first."
  echo "  git add -A && git commit -m 'pre-migration snapshot'"
  exit 1
fi

echo "=== Vault migration: flat → subdir layout ==="
moved=0
skipped=0
deleted=0

# ── Migrate projects/ ─────────────────────────────────────────────────────────
for src in projects/*.md; do
  [ -f "$src" ] || continue
  name="${src%.md}"        # projects/Foo
  base="${name#projects/}" # Foo

  # Skip: already-migrated subdir entries (won't exist as flat files after migration)
  # Skip: .hl highlighter artifacts
  if [[ "$base" == *.hl ]]; then
    git rm --force "$src" 2>/dev/null || rm -f "$src"
    echo "  DELETED $src (Highlighter artifact)"
    (( deleted++ )) || true
    continue
  fi

  dest="projects/${base}/${base}.md"
  if [ -f "$dest" ]; then
    echo "  SKIP $src (already migrated to $dest)"
    (( skipped++ )) || true
    continue
  fi

  mkdir -p "projects/${base}"
  git mv "$src" "$dest"
  echo "  MOVED $src → $dest"
  (( moved++ )) || true
done

# ── Migrate personal/Katusha.md ───────────────────────────────────────────────
for name in Katusha; do
  src="personal/${name}.md"
  dest="personal/${name}/${name}.md"
  if [ -f "$src" ]; then
    mkdir -p "personal/${name}"
    git mv "$src" "$dest"
    echo "  MOVED $src → $dest"
    (( moved++ )) || true
  elif [ -f "$dest" ]; then
    echo "  SKIP $src (already migrated)"
    (( skipped++ )) || true
  fi
done

# ── Fix [[projects/Foo]] → [[Foo]] wikilinks in knowledge notes ───────────────
echo ""
echo "=== Fixing [[projects/X]] wikilinks in knowledge/ ==="
# Also fix frontmatter: "[[projects/Foo]]" and projects: ["[[projects/Foo]]"] forms
fixed_files=0
while IFS= read -r -d '' f; do
  # Skip binary, skip .hl files
  [[ "$f" == *.hl ]] && continue
  if grep -q '\[\[projects/' "$f" 2>/dev/null; then
    # Replace [[projects/Foo]] → [[Foo]] (and quoted variants)
    sed -i 's|\[\[projects/\([^]|]*\)\]\]|\[\[\1\]\]|g' "$f"
    echo "  FIXED $f"
    git add "$f"
    (( fixed_files++ )) || true
  fi
done < <(find knowledge -name "*.md" -print0 2>/dev/null)

# Also fix projects/ plain-path entries in frontmatter (e.g. "  - projects/Desktop")
while IFS= read -r -d '' f; do
  [[ "$f" == *.hl ]] && continue
  if grep -qE '^\s*- projects/[A-Za-z]' "$f" 2>/dev/null; then
    sed -i 's|^\( *- \)projects/\([A-Za-z][^/]*\)$|\1\2|g' "$f"
    echo "  FIXED frontmatter paths in $f"
    git add "$f"
  fi
done < <(find knowledge -name "*.md" -print0 2>/dev/null)

# ── Stage deletions of any leftover .hl files not caught above ────────────────
for f in projects/*.hl personal/*.hl 2>/dev/null; do
  [ -f "$f" ] || continue
  git rm --force "$f" 2>/dev/null || rm -f "$f"
  echo "  DELETED $f"
  (( deleted++ )) || true
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "  Moved:   $moved"
echo "  Skipped: $skipped"
echo "  Deleted: $deleted"
echo "  Wikilink files fixed: $fixed_files"
echo ""
echo "Stage and commit:"
echo "  git add -A && git commit -m 'refactor: migrate projects to subdir layout'"
