#!/usr/bin/env bash
#
# doi2cite.sh — Convert a DOI to a formatted citation
#
# Usage:
#   ./doi2cite.sh [--doi] DOI [STYLE]
#
# e.g.
#   ./doi2cite.sh 10.1111/jeb.12043
#   ./doi2cite.sh --doi 10.1111/jeb.12043
#   ./doi2cite.sh 10.1111/jeb.12043 apa
#   ./doi2cite.sh https://doi.org/10.1111/jeb.12043
#
# Options:
#   --doi              Append the DOI link at the end of the citation
#   --italic-journal   Wrap journal name in *...* (markdown italic)
#
# NOTES:
#   - STYLE defaults to "molecular-biology-and-evolution" if not provided
#   - STYLE is a CSL style name (e.g. apa, nature, cell, chicago-author-date)
#   - See https://www.zotero.org/styles for available CSL styles
#   - DOI can be given with or without the https://doi.org/ prefix

APPEND_DOI=false
ITALIC_JOURNAL=false
while [[ "$1" == --* ]]; do
  case "$1" in
    --doi) APPEND_DOI=true; shift ;;
    --italic-journal) ITALIC_JOURNAL=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Strip whitespace and https://doi.org/ prefix if present
DOI="$(echo "$1" | xargs)"
DOI="${DOI#https://doi.org/}"
DOI="${DOI#http://doi.org/}"
DOI="${DOI#http://dx.doi.org/}"
DOI="${DOI#doi:}"

STYLE="${2:-molecular-biology-and-evolution}"

if [[ -z "$DOI" ]]; then
  echo "Usage: $0 [--doi] DOI [STYLE]"
  echo "  --doi  — append DOI link to the citation"
  echo "  DOI    — e.g. 10.1111/jeb.12043"
  echo "  STYLE  — CSL style name (default: molecular-biology-and-evolution)"
  echo ""
  echo "Examples:"
  echo "  $0 10.1111/jeb.12043"
  echo "  $0 --doi 10.1111/jeb.12043"
  echo "  $0 https://doi.org/10.1111/jeb.12043 apa"
  exit 1
fi

# Validate that DOI looks like a DOI (starts with 10.)
if [[ ! "$DOI" =~ ^10\. ]]; then
  echo "Error: '$DOI' does not look like a DOI (must start with 10.)" >&2
  exit 1
fi

# Use doi.org content negotiation to get a formatted citation
RESULT=$(curl -sL -w "\n%{http_code}" \
  -H "Accept: text/x-bibliography; style=${STYLE}" \
  "https://doi.org/${DOI}")

HTTP_CODE=$(echo "$RESULT" | tail -1)
BODY=$(echo "$RESULT" | sed '$d')

if [[ "$HTTP_CODE" -ge 400 ]]; then
  echo "Error: Failed to fetch citation (HTTP ${HTTP_CODE})" >&2
  echo "  DOI:   ${DOI}" >&2
  echo "  Style: ${STYLE}" >&2
  exit 1
fi

# --- Post-processing cleanup ---

# Join multiline output into single line, collapse whitespace
BODY=$(echo "$BODY" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')

# Remove editor names injected between title and journal
# CrossRef metadata sometimes includes ".EditorName(s), editor(s)." between title and journal
BODY=$(echo "$BODY" | perl -pe \
  's/\.\s*([A-Z][\w-]+ [A-Z]{1,4}(,\s*)?)+editors?\.\s*/. /g')

# Fetch CSL-JSON metadata once (used for title italic fix + journal italicization)
CSLJSON=$(curl -sL -H "Accept: application/vnd.citationstyles.csl+json" \
  "https://doi.org/${DOI}" 2>/dev/null)
ORIG_TITLE=$(echo "$CSLJSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('title',''))
" 2>/dev/null)
JOURNAL=$(echo "$CSLJSON" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ct=d.get('container-title','')
print(ct if isinstance(ct,str) else ct[0] if ct else '')
" 2>/dev/null)

# Fix missing spaces from stripped HTML tags in titles.
# The plain-text API strips <i>, <b> etc. without inserting spaces, causing
# merged words like "inHordeum spontaneumpopulations".
if [[ -n "$ORIG_TITLE" ]] && echo "$ORIG_TITLE" | grep -q '<[a-z]'; then
  MANGLED=$(echo "$ORIG_TITLE" | sed 's/<[^>]*>//g')
  FIXED=$(echo "$ORIG_TITLE" \
    | sed 's/<i>/ */g; s/<\/i>/* /g' \
    | sed 's/<[^>]*>/ /g; s/  */ /g; s/^ //; s/ $//')
  BODY=$(M="$MANGLED" F="$FIXED" perl -pe 's/\Q$ENV{M}\E/$ENV{F}/g' <<< "$BODY")
fi

# Strip remaining HTML tags (e.g., <scp>vcfr</scp> → vcfr)
BODY=$(echo "$BODY" | sed 's/<[^>]*>//g')

# Fix HTML entities
BODY=$(echo "$BODY" | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g')

# Fix double-encoded UTF-8 mojibake (e.g., Grünwald → Grünwald)
# Pattern: C3 83 C2 XX → C3 XX (chars U+00C0–U+00FF)
#          C3 82 C2 XX → C2 XX (chars U+0080–U+00BF)
BODY=$(echo "$BODY" | perl -pe '
  s/\xc3\x83\xc2([\x80-\xbf])/\xc3$1/g;
  s/\xc3\x82\xc2([\x80-\xbf])/\xc2$1/g;
')

# Clean up CSL artifacts:
#   - Remove "[Internet]" medium designation
#   - Remove "Available from: <URL>" suffix
BODY=$(echo "$BODY" \
  | sed 's/ \[Internet\]//g' \
  | sed 's/[. ]*Available from: [^ ]*//g')

# Fix ALL CAPS author names and titles
BODY=$(echo "$BODY" | perl -CSD -pe '
  use utf8;
  if (/^(.*?)(\d{4}\.\s*)(.+)/) {
    my ($auth, $year, $rest) = ($1, $2, $3);

    # Title-case ALL CAPS surnames (3+ uppercase letters) in author section
    $auth =~ s/\b(\p{Lu}{3,})\b/ucfirst(lc($1))/ge;

    # Fix hyphenated initials: H-G → HG
    $auth =~ s/(?<= )([A-Z])-([A-Z])(?=[, .])/$1$2/g;

    # Fix lowercase multi-char initials: Gbm → GBM (only after 3+ char surnames)
    $auth =~ s/\w{3,} \K([A-Z][a-z]{1,2})\b/uc($1)/ge;

    # Strip stray backticks from author names
    $auth =~ s/`//g;

    # Detect ALL CAPS title and convert to sentence case
    # Title: text before ". Journal Volume:Pages" pattern
    if ($rest =~ /^(.+?)\.\s+(.*\d+[:\(].*)$/) {
      my ($title, $journal) = ($1, $2);
      my $letters = $title =~ s/[^\p{L}]//gr;
      my $upper = () = $letters =~ /\p{Lu}/g;
      my $total = length($letters);
      if ($total > 10 && ($upper / $total) > 0.8) {
        $title = ucfirst(lc($title));
      }
      $rest = "$title. $journal";
    }
    $_ = "$auth$year$rest";
  }
')

# Normalize Unicode whitespace (NBSP, narrow NBSP, etc.) to regular space
BODY=$(echo "$BODY" | perl -CSD -pe 's/[\x{00A0}\x{2000}-\x{200B}\x{202F}\x{205F}\x{3000}]/ /g')

# Italicize journal name if requested
if [[ "$ITALIC_JOURNAL" == true ]] && [[ -n "$JOURNAL" ]]; then
  # Replace only the last occurrence (journal appears after title)
  BODY=$(J="$JOURNAL" perl -CSD -pe 'use utf8; s/(.*)(\Q$ENV{J}\E)/$1*$ENV{J}*/s' <<< "$BODY")
fi

# Final whitespace cleanup and trailing period
BODY=$(echo "$BODY" | sed 's/  */ /g; s/^ //; s/ $//; s/[. ]*$/./')

# Append DOI if requested
if [[ "$APPEND_DOI" == true ]]; then
  BODY="${BODY} https://doi.org/${DOI}"
fi

echo "$BODY"
