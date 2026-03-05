#!/usr/bin/env bash
set -euo pipefail

BASELINE_FILE="docs/M4_DEBUG_PASS_BASELINES.txt"
OUT_DIR="/tmp/mtc_m4_debug_pass_pack"

./scripts/capture_m4_debug_pass_pack.sh "${OUT_DIR}"

hash_of() {
  local id="$1"
  sha256sum "${OUT_DIR}/${id}.ppm" | awk '{print $1}'
}

uniq_of() {
  local id="$1"
  awk 'NR>3 {print $0}' "${OUT_DIR}/${id}.ppm" | sort -u | wc -l
}

{
  echo "# Milestone 4 debug-pass baselines"
  echo "# Re-generate with: scripts/rebaseline_m4_debug_pass_pack.sh"
  echo "# Format: id sha256 unique_colors_min"
  for id in \
    add_mid_depth sub_mid_depth shift_mid_depth mul_mid_depth mul_final_depth \
    add_mid_role_id sub_mid_role_id shift_mid_role_id mul_mid_role_id mul_final_role_id
  do
    echo "${id} $(hash_of "${id}") $(uniq_of "${id}")"
  done
} > "${BASELINE_FILE}"

echo "REBASELINE_M4_DEBUG_PASS_OK file=${BASELINE_FILE}"
