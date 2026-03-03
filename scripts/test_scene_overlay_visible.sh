#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SMOKE_EXE:-}" ]]; then
  echo "ERROR: SMOKE_EXE must be set to the Win64 executable path." >&2
  exit 2
fi

OUT1_POSIX="/tmp/matter_scene_frame1.ppm"
OUT2_POSIX="/tmp/matter_scene_frame2.ppm"
OUT1_WIN='Z:\\tmp\\matter_scene_frame1.ppm'
OUT2_WIN='Z:\\tmp\\matter_scene_frame2.ppm'
rm -f "$OUT1_POSIX" "$OUT2_POSIX"

run_capture() {
  local frames="$1"
  local out_win="$2"
  MTC_DISABLE_PROTON="${MTC_DISABLE_PROTON:-1}" \
  MTC_FRAMES="$frames" \
  MTC_SEED="${MTC_SEED:-1}" \
  MTC_EXTRA_ARGS="--width 256 --height 256 --screenshot-out $out_win" \
  SMOKE_EXE="$SMOKE_EXE" \
  ./scripts/run_windows_smoke.sh
}

run_capture 1 "$OUT1_WIN"
run_capture 45 "$OUT2_WIN"

for f in "$OUT1_POSIX" "$OUT2_POSIX"; do
  if [[ ! -s "$f" ]]; then
    echo "ERROR: screenshot file not created: $f" >&2
    exit 3
  fi
  if [[ "$(head -n 1 "$f")" != "P3" ]]; then
    echo "ERROR: screenshot is not a P3 PPM file: $f" >&2
    exit 4
  fi
done

u1="$(awk 'NR > 3 { print }' "$OUT1_POSIX" | sort -u | wc -l)"
u2="$(awk 'NR > 3 { print }' "$OUT2_POSIX" | sort -u | wc -l)"
if (( u1 <= 2 || u2 <= 2 )); then
  echo "ERROR: overlay not visible; color count still checker-like (u1=$u1 u2=$u2)." >&2
  exit 5
fi

h1="$(sha256sum "$OUT1_POSIX" | awk '{print $1}')"
h2="$(sha256sum "$OUT2_POSIX" | awk '{print $1}')"
if [[ "$h1" == "$h2" ]]; then
  echo "ERROR: overlay appears static across timesteps (hash=$h1)." >&2
  exit 6
fi

echo "SCENE_OVERLAY_VISIBLE_OK u1=$u1 u2=$u2 h1=$h1 h2=$h2"
