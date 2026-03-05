#!/usr/bin/env bash
set -euo pipefail

# Capture a curated set of deterministic keyframes for Milestone 4 manual review.
# Requires: SMOKE_EXE (or discovery through scripts/find_win64_exe.sh)

if [[ -z "${SMOKE_EXE:-}" ]]; then
  SMOKE_EXE="$(./scripts/find_win64_exe.sh "$PWD")"
fi

if [[ ! -f "${SMOKE_EXE}" ]]; then
  echo "ERROR: SMOKE_EXE not found: ${SMOKE_EXE}" >&2
  exit 2
fi

OUT_DIR="${1:-/tmp/mtc_m4_review_pack}"
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
  MTC_EXTRA_ARGS="--scene ${scene} --camera ${camera} --width 640 --height 360 --screenshot-out ${out_win}" \
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

# tick_count=5, phase_frames=30
# add_mid       => frame 15
# sub_mid       => frame 42
# shift_mid     => frame 15
# mul_mid       => frame 75
# add_final     => frame 149
# mul_final     => frame 149
capture_one "add_mid_story" "add" "storyboard" 16
capture_one "add_mid_cine" "add" "cinematic" 16
capture_one "sub_mid_story" "sub" "storyboard" 43
capture_one "shift_mid_cine" "shift" "cinematic" 16
capture_one "mul_mid_story" "mul" "storyboard" 76
capture_one "mul_mid_cine" "mul" "cinematic" 76
capture_one "add_final_story" "add" "storyboard" 150
capture_one "mul_final_story" "mul" "storyboard" 150

manifest="${OUT_DIR}/MANIFEST.txt"
{
  echo "# Milestone 4 review pack"
  echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Format: id sha256 unique_colors"
  for id in \
    add_mid_story add_mid_cine sub_mid_story shift_mid_cine \
    mul_mid_story mul_mid_cine add_final_story mul_final_story
  do
    sha="$(sha256sum "${OUT_DIR}/${id}.ppm" | awk '{print $1}')"
    uniq="$(awk 'NR>3 {print $0}' "${OUT_DIR}/${id}.ppm" | sort -u | wc -l)"
    echo "${id} ${sha} ${uniq}"
  done
} > "${manifest}"

echo "M4_REVIEW_PACK_OK out_dir=${OUT_DIR} manifest=${manifest}"
