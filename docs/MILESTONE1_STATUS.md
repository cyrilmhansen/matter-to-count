# Milestone 1 Status (Technical Spine)

Date: March 3, 2026

## Completed
- Win64 cross-build from Linux (`zig build win64`).
- Mandatory post-build binary sanity check integrated into `win64`.
- Win32 window creation + message pump (`src/platform/win32/window.zig`).
- D3D11 device + swapchain initialization (`src/render/d3d11.zig`).
- D3D11 init diagnostics with fallback attempts:
  - hardware driver first;
  - WARP fallback attempt;
  - HRESULT logging on failures.
- Runtime loop wired in Windows app path (`src/app/app.zig`).
- Deterministic smoke mode (`--smoke --frames --seed`) with success marker.
- End-to-end smoke gate integrated into build (`zig build smoke-win64`).

## Validated Commands
- `zig build test`
- `zig build win64`
- `MTC_DISABLE_PROTON=1 MTC_FRAMES=60 MTC_SEED=1 zig build smoke-win64`

## Current Runtime Notes
- Wine smoke path is stable and emits `SMOKE_OK`.
- Proton path is supported by scripts but still environment-sensitive.
- `DXGI` missing from import table is treated as warning (not failure).

## Explicit Render-Clear Note
- An explicit RTV clear path was prototyped but caused instability under Wine with current hand-written COM vtable bindings.
- For Milestone 1 stability, runtime uses a present-only render loop after successful D3D11 init.
- Next recommended step: switch D3D11 bindings to generated/authoritative headers or validated bindings package before re-enabling explicit clear/draw calls.

## Milestone 1 Exit Criteria (Practical)
- `zig build smoke-win64` passes on the reference Linux machine.
- `zig build win64` always includes binary sanity checks.
- App creates a Win32 window and D3D11 device reliably under emulation.
- Deterministic smoke output includes `SMOKE_OK` and stable scene hash.
