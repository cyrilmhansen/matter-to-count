#!/usr/bin/env bash
set -euo pipefail

BASELINE_FILE="docs/M4_DEBUG_PASS_BASELINES.txt"
OUT_DIR="/tmp/mtc_m4_debug_pass_pack"

if [[ ! -f "${BASELINE_FILE}" ]]; then
  echo "ERROR: missing baseline file ${BASELINE_FILE}. Run scripts/rebaseline_m4_debug_pass_pack.sh first." >&2
  exit 2
fi

./scripts/capture_m4_debug_pass_pack.sh "${OUT_DIR}"

fail=0
while read -r id sha uniq_min; do
  [[ -z "${id}" || "${id}" == \#* ]] && continue
  file="${OUT_DIR}/${id}.ppm"
  if [[ ! -s "${file}" ]]; then
    echo "ERROR: missing capture ${file}" >&2
    fail=1
    continue
  fi
  actual_sha="$(sha256sum "${file}" | awk '{print $1}')"
  actual_uniq="$(awk 'NR>3 {print $0}' "${file}" | sort -u | wc -l)"
  if [[ "${actual_sha}" != "${sha}" ]]; then
    echo "ERROR: hash mismatch ${id} expected=${sha} actual=${actual_sha}" >&2
    fail=1
  fi
  if (( actual_uniq < uniq_min )); then
    echo "ERROR: low color diversity ${id} min=${uniq_min} actual=${actual_uniq}" >&2
    fail=1
  fi
done < "${BASELINE_FILE}"

if (( fail != 0 )); then
  exit 3
fi

echo "M4_DEBUG_PASS_BASELINES_OK baseline=${BASELINE_FILE}"
