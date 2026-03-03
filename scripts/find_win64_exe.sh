#!/usr/bin/env bash
set -euo pipefail

root="${1:-$PWD}"
exe="$(find "$root/.zig-cache" -type f -name 'matter-to-count-win64.exe' -printf '%T@ %p\n' | sort -n | tail -n 1 | cut -d' ' -f2-)"

if [[ -z "$exe" ]]; then
  echo "" >&2
  exit 1
fi

printf '%s\n' "$exe"
