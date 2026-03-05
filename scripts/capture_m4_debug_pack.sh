#!/usr/bin/env bash
set -euo pipefail

# Capture deterministic debug-camera frames for Milestone 4 staging review.
# Requires: SMOKE_EXE (or discovery via scripts/find_win64_exe.sh)

if [[ -z "${SMOKE_EXE:-}" ]]; then
  SMOKE_EXE="$(./scripts/find_win64_exe.sh "$PWD")"
fi

if [[ ! -f "${SMOKE_EXE}" ]]; then
  echo "ERROR: SMOKE_EXE not found: ${SMOKE_EXE}" >&2
  exit 2
fi

OUT_DIR="${1:-/tmp/mtc_m4_debug_pack}"
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
capture_one "add_mid_debug" "add" "debug" 16
capture_one "sub_mid_debug" "sub" "debug" 43
capture_one "shift_mid_debug" "shift" "debug" 16
capture_one "mul_mid_debug" "mul" "debug" 76
capture_one "mul_final_debug" "mul" "debug" 150

manifest="${OUT_DIR}/MANIFEST.txt"
{
  echo "# Milestone 4 debug pack"
  echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Format: id sha256 unique_colors"
  for id in add_mid_debug sub_mid_debug shift_mid_debug mul_mid_debug mul_final_debug
  do
    sha="$(sha256sum "${OUT_DIR}/${id}.ppm" | awk '{print $1}')"
    uniq="$(awk 'NR>3 {print $0}' "${OUT_DIR}/${id}.ppm" | sort -u | wc -l)"
    echo "${id} ${sha} ${uniq}"
  done
} > "${manifest}"

echo "M4_DEBUG_PACK_OK out_dir=${OUT_DIR} manifest=${manifest}"
