#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SMOKE_EXE:-}" ]]; then
  echo "ERROR: SMOKE_EXE must be set to the Win64 executable path." >&2
  exit 2
fi

OUT_POSIX="/tmp/matter_checkerboard.ppm"
OUT_WIN='Z:\\tmp\\matter_checkerboard.ppm'
rm -f "$OUT_POSIX"

MTC_DISABLE_PROTON="${MTC_DISABLE_PROTON:-1}" \
MTC_FRAMES="${MTC_FRAMES:-30}" \
MTC_SEED="${MTC_SEED:-1}" \
MTC_EXTRA_ARGS="--width 128 --height 128 --screenshot-out $OUT_WIN" \
SMOKE_EXE="$SMOKE_EXE" \
./scripts/run_windows_smoke.sh

if [[ ! -s "$OUT_POSIX" ]]; then
  echo "ERROR: screenshot file not created: $OUT_POSIX" >&2
  exit 3
fi

if [[ "$(head -n 1 "$OUT_POSIX")" != "P3" ]]; then
  echo "ERROR: screenshot is not a P3 PPM file." >&2
  exit 4
fi

unique_colors="$(awk 'NR > 3 && NR <= 4099 { print }' "$OUT_POSIX" | sort -u | wc -l)"
if (( unique_colors < 2 )); then
  echo "ERROR: screenshot appears uniform; checkerboard not visible." >&2
  exit 5
fi

echo "CHECKERBOARD_VISIBLE_OK file=$OUT_POSIX unique_colors=$unique_colors"
