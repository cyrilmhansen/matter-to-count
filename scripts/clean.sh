#!/usr/bin/env bash
set -euo pipefail

# Keep cleanup explicit and local to repository-generated artifacts.
rm -rf \
  .zig-cache \
  zig-out \
  .gradle \
  android/.gradle \
  android/app/build \
  android/build
