#!/usr/bin/env bash
set -euo pipefail

# Capture deterministic raymarch keyframes as PPMs.
# Requires: SMOKE_EXE (or discover via scripts/find_win64_exe.sh)

if [[ -z "${SMOKE_EXE:-}" ]]; then
  SMOKE_EXE="$(./scripts/find_win64_exe.sh "$PWD")"
fi

if [[ ! -f "${SMOKE_EXE}" ]]; then
  echo "ERROR: SMOKE_EXE not found: ${SMOKE_EXE}" >&2
  exit 2
fi

OUT_DIR="${1:-/tmp/mtc_raymarch_keyframes}"
mkdir -p "${OUT_DIR}"

capture_one() {
  local id="$1"
  local scene="$2"
  local camera="$3"
  local frames="$4"
  local tmp_posix="/tmp/${id}.ppm"
  local out_posix="${OUT_DIR}/${id}.ppm"
  local out_win="Z:\\tmp\\${id}.ppm"
  rm -f "${tmp_posix}" "${out_posix}"

  MTC_DISABLE_PROTON="${MTC_DISABLE_PROTON:-1}" \
  MTC_FRAMES="${frames}" \
  MTC_SEED="${MTC_SEED:-1}" \
  MTC_EXTRA_ARGS="--scene ${scene} --camera ${camera} --width 320 --height 180 --screenshot-out ${out_win}" \
  SMOKE_EXE="${SMOKE_EXE}" \
  ./scripts/run_windows_smoke.sh >/tmp/${id}.log 2>&1

  if [[ ! -s "${tmp_posix}" ]]; then
    echo "ERROR: missing capture ${out_posix}" >&2
    cat "/tmp/${id}.log" >&2 || true
    exit 3
  fi
  if [[ "$(head -n 1 "${tmp_posix}")" != "P3" ]]; then
    echo "ERROR: invalid PPM for ${id}" >&2
    exit 4
  fi
  cp "${tmp_posix}" "${out_posix}"
}

# frame mapping: tick_count=5, phase_frames=30
# add_mid: tick0 phase0.5 => frame 15
# sub_mid: tick1 phase0.4 => frame 42
# shift_mid: tick0 phase0.5 => frame 15
# mul_mid: tick2 phase0.5 => frame 75
# mul_final-ish: tick4 phase29/30 => frame 149
capture_one "add_mid_cine" "add" "cinematic" 16
capture_one "sub_mid_story" "sub" "storyboard" 43
capture_one "shift_mid_cine" "shift" "cinematic" 16
capture_one "mul_mid_cine" "mul" "cinematic" 76
capture_one "mul_final_story" "mul" "storyboard" 150

echo "CAPTURE_RAYMARCH_KEYFRAMES_OK out_dir=${OUT_DIR}"
