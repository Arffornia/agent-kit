#!/usr/bin/env bash
# Render Noodle views of the Arffornia docs repo to .drawio, PNG and editable SVG, headless.
#
# Usage (from the docs repo root):
#   export.sh                 # every view in architecture/arffornia/views, dark and light
#   export.sh runtime tech-stack
#   CHECK_ONLY=1 export.sh    # noodle check + lint only (what `make check` runs)
#
# Why the flags: draw.io is Electron. Without a GPU or display it needs xvfb and software GL
# (`--no-sandbox --use-angle=swiftshader --enable-unsafe-swiftshader`), otherwise it exits 0
# with an empty or black PNG. Headless exports wider than ~3900 px get cropped, so the PNG
# scale is min(2, 3900 / (pageWidth + 40)), the same rule as `make diagrams`.
set -euo pipefail
SYSTEM=${SYSTEM:-architecture/arffornia}
OUT=${OUT:-docs/assets/diagrams}
ICONS=${ICONS:--icons .noodle/icons}
[ -d "$SYSTEM/views" ] || { echo "export.sh: $SYSTEM/views not found; run from the docs repo root" >&2; exit 2; }
command -v noodle >/dev/null || { echo "export.sh: noodle not on PATH (TheGostsniperfr/Noodle bin/)" >&2; exit 2; }

if [ $# -gt 0 ]; then VIEWS=("$@"); else
  VIEWS=()   # portable loop: macOS bash 3.2 lacks the bash 4 array readers
  for f in "$SYSTEM"/views/*.yaml; do [ -f "$f" ] && VIEWS+=("$(basename "$f" .yaml)"); done
fi

for v in "${VIEWS[@]}"; do
  echo "noodle: $v"
  # shellcheck disable=SC2086
  noodle render "$SYSTEM" -view "$v" $ICONS
done
[ -n "${CHECK_ONLY:-}" ] && { echo "lint ok: ${#VIEWS[@]} view(s)"; exit 0; }

DRAWIO_BIN=drawio
if ! command -v drawio >/dev/null && [ -x "/Applications/draw.io.app/Contents/MacOS/draw.io" ]; then
  DRAWIO_BIN="/Applications/draw.io.app/Contents/MacOS/draw.io"   # macOS app (brew install --cask drawio)
fi
command -v "$DRAWIO_BIN" >/dev/null || { echo "export.sh: drawio missing; .drawio files only" >&2; NO_DRAWIO=1; }
XVFB=()
if [ "$(uname -s)" != Darwin ] && [ -z "${DISPLAY:-}" ]; then   # macOS has a window server: no xvfb
  command -v xvfb-run >/dev/null || { echo "export.sh: no DISPLAY and no xvfb-run" >&2; exit 2; }
  XVFB=(xvfb-run -a -s "-screen 0 1920x1080x24")
fi
DRAWIO=("${XVFB[@]+"${XVFB[@]}"}" "$DRAWIO_BIN" --no-sandbox --use-angle=swiftshader --enable-unsafe-swiftshader)

mkdir -p "$OUT"
for v in "${VIEWS[@]}"; do
  for t in dark light; do
    B="$OUT/$v.$t"
    # shellcheck disable=SC2086
    noodle render "$SYSTEM" -view "$v" $ICONS -theme "$t" -o "$B.drawio"
    [ -n "${NO_DRAWIO:-}" ] && continue
    W=$(grep -o 'pageWidth="[0-9]*"' "$B.drawio" | head -1 | tr -dc 0-9)
    S=$(awk -v w="${W:-1000}" 'BEGIN{s=3900/(w+40); if(s>2)s=2; printf "%.2f", s}')
    "${DRAWIO[@]}" -x -f png -s "$S" --border 20 -o "$B.png" "$B.drawio" 2>/dev/null
    "${DRAWIO[@]}" -x -f svg --embed-diagram -o "$B.drawio.svg" "$B.drawio" 2>/dev/null
    [ -s "$B.png" ] || { echo "export.sh: $B.png is empty (draw.io failed headless)" >&2; exit 1; }
    echo "  $B.png (scale $S, pageWidth ${W:-?}) + $B.drawio.svg"
  done
done
