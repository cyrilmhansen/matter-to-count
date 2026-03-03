#!/usr/bin/env bash
set -euo pipefail

# Runs a Windows build artifact under Proton (preferred) or Wine (fallback).
# Intended for deterministic smoke checks on Linux.

if [[ -z "${SMOKE_EXE:-}" ]]; then
  echo "ERROR: SMOKE_EXE is required (absolute path to .exe)." >&2
  exit 2
fi

if [[ ! -f "${SMOKE_EXE}" ]]; then
  echo "ERROR: executable not found: ${SMOKE_EXE}" >&2
  exit 2
fi

MTC_FRAMES="${MTC_FRAMES:-120}"
MTC_SEED="${MTC_SEED:-1}"
MTC_EXTRA_ARGS="${MTC_EXTRA_ARGS:-}"
MTC_DISABLE_PROTON="${MTC_DISABLE_PROTON:-0}"
STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$PWD/.steam-compat/matter-to-count}"
STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-}"

extra_args=()
if [[ -n "${MTC_EXTRA_ARGS}" ]]; then
  read -r -a extra_args <<<"${MTC_EXTRA_ARGS}"
fi

RUNTIME=""
if [[ "${MTC_DISABLE_PROTON}" != "1" ]]; then
  if [[ -n "${PROTON_BIN:-}" ]]; then
    RUNTIME="${PROTON_BIN}"
  elif [[ -x "/usr/share/steam/compatibilitytools.d/proton-cachyos/proton" ]]; then
    RUNTIME="/usr/share/steam/compatibilitytools.d/proton-cachyos/proton"
  elif command -v proton >/dev/null 2>&1; then
    RUNTIME="$(command -v proton)"
  fi
fi

if [[ -z "${RUNTIME}" ]] && command -v wine >/dev/null 2>&1; then
  RUNTIME="$(command -v wine)"
fi

if [[ -z "${RUNTIME}" ]]; then
  echo "ERROR: neither Proton nor Wine found." >&2
  exit 3
fi

echo "Using runtime: ${RUNTIME}"
echo "SMOKE_EXE=${SMOKE_EXE}"
echo "MTC_FRAMES=${MTC_FRAMES} MTC_SEED=${MTC_SEED}"

tmp_log="$(mktemp)"
trap 'rm -f "$tmp_log"' EXIT

if [[ "$(basename "${RUNTIME}")" == "proton" ]]; then
  if [[ -z "${STEAM_COMPAT_CLIENT_INSTALL_PATH}" ]]; then
    for candidate in "/usr/share/steam" "/usr/lib/steam" "$HOME/.steam/steam"; do
      if [[ -d "${candidate}" ]]; then
        STEAM_COMPAT_CLIENT_INSTALL_PATH="${candidate}"
        break
      fi
    done
  fi
  if [[ -z "${STEAM_COMPAT_CLIENT_INSTALL_PATH}" ]]; then
    echo "ERROR: Proton requires STEAM_COMPAT_CLIENT_INSTALL_PATH. Set it explicitly." >&2
    exit 4
  fi
  mkdir -p "${STEAM_COMPAT_DATA_PATH}"
  export STEAM_COMPAT_DATA_PATH
  export STEAM_COMPAT_CLIENT_INSTALL_PATH
  "${RUNTIME}" run "${SMOKE_EXE}" --smoke --frames "${MTC_FRAMES}" --seed "${MTC_SEED}" "${extra_args[@]}" 2>&1 | tee "$tmp_log"
else
  "${RUNTIME}" "${SMOKE_EXE}" --smoke --frames "${MTC_FRAMES}" --seed "${MTC_SEED}" "${extra_args[@]}" 2>&1 | tee "$tmp_log"
fi

if ! rg -q "^SMOKE_OK " "$tmp_log"; then
  echo "ERROR: Smoke run did not emit SMOKE_OK marker." >&2
  exit 5
fi
