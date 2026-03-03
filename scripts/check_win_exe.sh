#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

EXE_PATH="${1:-${SMOKE_EXE:-}}"
if [[ -z "${EXE_PATH}" ]]; then
  echo "ERROR: pass exe path as arg1 or set SMOKE_EXE" >&2
  exit 2
fi
if [[ ! -f "${EXE_PATH}" ]]; then
  echo "ERROR: file not found: ${EXE_PATH}" >&2
  exit 2
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required tool: $1" >&2
    exit 3
  fi
}

need_cmd file

file_out="$(file "${EXE_PATH}")"
echo "[file] ${file_out}"

if ! grep -q "PE32+ executable" <<<"${file_out}"; then
  echo "ERROR: not a PE32+ executable" >&2
  exit 10
fi
if ! grep -q "x86-64" <<<"${file_out}"; then
  echo "ERROR: binary is not x86-64" >&2
  exit 11
fi

if command -v objdump >/dev/null 2>&1; then
  echo "[objdump] checking PE headers/imports"
  objdump_out="$(objdump -p "${EXE_PATH}")"
  if ! grep -q "Subsystem" <<<"${objdump_out}"; then
    echo "ERROR: objdump output missing Subsystem" >&2
    exit 12
  fi
  # Accept either legacy kernel32 or newer kernelbase forwarding patterns.
  if ! grep -Eqi "DLL Name: (KERNEL32|KERNELBASE)\.dll" <<<"${objdump_out}"; then
    echo "ERROR: expected core Win32 import (KERNEL32 or KERNELBASE) not found" >&2
    exit 13
  fi
  if ! grep -Eq "DLL Name: (D3D11\.dll|d3d11\.dll)" <<<"${objdump_out}"; then
    echo "ERROR: expected D3D11 import not found" >&2
    exit 14
  fi
  if ! grep -Eq "DLL Name: (DXGI\.dll|dxgi\.dll)" <<<"${objdump_out}"; then
    echo "WARN: DXGI import not found in table (may be transitively loaded by D3D11)." >&2
  fi
  if ! grep -Eq "DLL Name: (USER32\.dll|user32\.dll)" <<<"${objdump_out}"; then
    echo "ERROR: expected USER32 import not found" >&2
    exit 15
  fi
else
  echo "[objdump] not available, skipping import checks"
fi

if command -v winedump >/dev/null 2>&1; then
  echo "[winedump] checking image characteristics"
  winedump -f "${EXE_PATH}" >/tmp/matter_to_count_winedump.txt
  if ! rg -q "Machine.*x86_64|8664|AMD64" /tmp/matter_to_count_winedump.txt; then
    echo "ERROR: winedump did not confirm x64 machine type" >&2
    exit 16
  fi
fi

echo "CHECK_WIN_EXE_OK path=${EXE_PATH}"
