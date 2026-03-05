#!/usr/bin/env bash
set -euo pipefail

BASELINE_FILE="docs/RAYMARCH_KEYFRAME_BASELINES.txt"
OUT_DIR="/tmp/mtc_raymarch_keyframes"

./scripts/capture_raymarch_keyframes.sh "${OUT_DIR}"

hash_of() {
  local id="$1"
  sha256sum "${OUT_DIR}/${id}.ppm" | awk '{print $1}'
}

uniq_of() {
  local id="$1"
  awk 'NR>3 {print $0}' "${OUT_DIR}/${id}.ppm" | sort -u | wc -l
}

{
  echo "# Raymarch keyframe baselines"
  echo "# Re-generate with: scripts/rebaseline_raymarch_keyframes.sh"
  echo "# Format: id sha256 unique_colors_min"
  echo "add_mid_cine $(hash_of add_mid_cine) $(uniq_of add_mid_cine)"
  echo "mul_mid_cine $(hash_of mul_mid_cine) $(uniq_of mul_mid_cine)"
  echo "mul_final_story $(hash_of mul_final_story) $(uniq_of mul_final_story)"
} > "${BASELINE_FILE}"

echo "REBASELINE_RAYMARCH_OK file=${BASELINE_FILE}"
