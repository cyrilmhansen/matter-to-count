#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOW_FILE="${ROOT_DIR}/scripts/cimport_allowed_paths.txt"

if [[ ! -f "${ALLOW_FILE}" ]]; then
  echo "ERROR: missing cimport allowlist: ${ALLOW_FILE}" >&2
  exit 2
fi

mapfile -t found < <(cd "${ROOT_DIR}" && rg -n "@cImport" src --no-heading | cut -d: -f1 | sort -u)
mapfile -t allowed < <(grep -E '^src/.+' "${ALLOW_FILE}" | sort -u)

extra=()
for p in "${found[@]:-}"; do
  [[ -z "${p}" ]] && continue
  if ! printf '%s\n' "${allowed[@]}" | grep -qx "${p}"; then
    extra+=("${p}")
  fi
done

missing=()
for p in "${allowed[@]:-}"; do
  [[ -z "${p}" ]] && continue
  if ! printf '%s\n' "${found[@]}" | grep -qx "${p}"; then
    missing+=("${p}")
  fi
done

if [[ "${#extra[@]}" -gt 0 ]]; then
  echo "ERROR: unexpected @cImport usage outside boundary:" >&2
  printf '  - %s\n' "${extra[@]}" >&2
  exit 3
fi

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "ERROR: allowlisted @cImport file missing usage (allowlist stale):" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 4
fi

echo "CHECK_CIMPORT_BOUNDARY_OK files=${#found[@]}"
