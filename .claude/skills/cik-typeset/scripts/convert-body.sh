#!/usr/bin/env bash
# CiK typesetting — mechanical Word -> Quarto body conversion (pinned Pandoc flags).
#
# Usage: convert-body.sh <manuscript.docx> [out-dir]
#
# Produces a MECHANICAL body file (_body.generated.qmd) and extracts embedded
# media into <out-dir>/media. This output is regenerated every run and must
# NEVER be hand-edited — the curated article lives in a separate
# <lastname>-<word>.qmd assembled from it. See SKILL.md ("Idempotency").
#
# Pinned flags (keep diffs stable across re-runs):
#   --from=docx
#   --to=markdown+tex_math_dollars-simple_tables-multiline_tables-grid_tables+pipe_tables
#   --wrap=none
#   --markdown-headings=atx
#   --extract-media=media
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <manuscript.docx> [out-dir]" >&2
  exit 2
fi

INPUT="$1"
[[ -f "$INPUT" ]] || { echo "Input manuscript not found: $INPUT" >&2; exit 1; }
case "$INPUT" in
  *.docx) ;;
  *) echo "Expected a .docx file. Re-save legacy .doc as .docx first." >&2; exit 1;;
esac

INPUT_ABS="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
OUTDIR="${2:-$(dirname "$INPUT")}"
mkdir -p "$OUTDIR"
OUTDIR="$(cd "$OUTDIR" && pwd)"
OUTBODY="$OUTDIR/_body.generated.qmd"

TO_FMT='markdown+tex_math_dollars-simple_tables-multiline_tables-grid_tables+pipe_tables'
PANDOC_ARGS=(
  "$INPUT_ABS"
  --from=docx
  --to="$TO_FMT"
  --wrap=none
  --markdown-headings=atx
  --extract-media=media
  --output "$OUTBODY"
)

# Prefer standalone pandoc; fall back to Quarto's bundled pandoc.
cd "$OUTDIR"
if command -v pandoc >/dev/null 2>&1; then
  echo "Using pandoc: $(command -v pandoc)"
  pandoc "${PANDOC_ARGS[@]}"
elif command -v quarto >/dev/null 2>&1; then
  echo "Standalone pandoc not found; using bundled 'quarto pandoc'."
  quarto pandoc "${PANDOC_ARGS[@]}"
else
  echo "Neither 'pandoc' nor 'quarto' found on PATH. Install Quarto 1.6+ (bundles Pandoc 3.4+)." >&2
  exit 1
fi

echo ""
echo "Wrote mechanical body : $OUTBODY"
if [[ -d "$OUTDIR/media" ]]; then
  n=$(find "$OUTDIR/media" -type f | wc -l | tr -d ' ')
  echo "Extracted media       : $OUTDIR/media ($n file(s))"
  echo "  -> Move real figures into figures/ as fig_1, fig_2, ...; discard logos/equation rasters."
else
  echo "No embedded media found (figures likely supplied as separate files)."
fi
echo ""
echo "NEXT: do not edit _body.generated.qmd. Assemble <lastname>-<word>.qmd from it (see SKILL.md)."
