#!/usr/bin/env bash
set -euo pipefail

# Capture deterministic debug-pass keyframes (depth + role-id) for M4 review.
# Requires: SMOKE_EXE (or discovery via scripts/find_win64_exe.sh)

if [[ -z "${SMOKE_EXE:-}" ]]; then
  SMOKE_EXE="$(./scripts/find_win64_exe.sh "$PWD")"
fi

if [[ ! -f "${SMOKE_EXE}" ]]; then
  echo "ERROR: SMOKE_EXE not found: ${SMOKE_EXE}" >&2
  exit 2
fi

OUT_DIR="${1:-/tmp/mtc_m4_debug_pass_pack}"
mkdir -p "${OUT_DIR}"

capture_one() {
  local id="$1"
  local scene="$2"
  local camera="$3"
  local view="$4"
  local frames="$5"
  local tmp_posix="/tmp/${id}.ppm"
  local out_posix="${OUT_DIR}/${id}.ppm"
  local out_win="Z:\\tmp\\${id}.ppm"
  rm -f "${tmp_posix}" "${out_posix}"

  MTC_DISABLE_PROTON="${MTC_DISABLE_PROTON:-1}" \
  MTC_FRAMES="${frames}" \
  MTC_SEED="${MTC_SEED:-1}" \
  MTC_EXTRA_ARGS="--scene ${scene} --camera ${camera} --view ${view} --width 640 --height 360 --screenshot-out ${out_win}" \
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
for view in depth role-id; do
  suffix="$(echo "$view" | tr '-' '_')"
  capture_one "add_mid_${suffix}" "add" "debug" "$view" 16
  capture_one "sub_mid_${suffix}" "sub" "debug" "$view" 43
  capture_one "shift_mid_${suffix}" "shift" "debug" "$view" 16
  capture_one "mul_mid_${suffix}" "mul" "debug" "$view" 76
  capture_one "mul_final_${suffix}" "mul" "debug" "$view" 150
done

manifest="${OUT_DIR}/MANIFEST.txt"
{
  echo "# Milestone 4 debug-pass pack"
  echo "# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Format: id sha256 unique_colors"
  for id in \
    add_mid_depth sub_mid_depth shift_mid_depth mul_mid_depth mul_final_depth \
    add_mid_role_id sub_mid_role_id shift_mid_role_id mul_mid_role_id mul_final_role_id
  do
    sha="$(sha256sum "${OUT_DIR}/${id}.ppm" | awk '{print $1}')"
    uniq="$(awk 'NR>3 {print $0}' "${OUT_DIR}/${id}.ppm" | sort -u | wc -l)"
    echo "${id} ${sha} ${uniq}"
  done
} > "${manifest}"

echo "M4_DEBUG_PASS_PACK_OK out_dir=${OUT_DIR} manifest=${manifest}"
