# Feature Spike: Generated D3D11 Bindings

Branch: `feature/m1-clear-draw-texture-spike`
Date: March 3, 2026

## Implemented
- Renderer switched to Windows-header based bindings via `@cImport` (`windows.h`, `d3d11.h`, `dxgi.h`).
- Explicit D3D11 render path restored:
  - bind RTV
  - set viewport
  - clear render target
  - present
- Procedural texture source added:
  - 64x64 checkerboard generated on CPU
  - uploaded as `ID3D11Texture2D`
  - `ID3D11ShaderResourceView` created and retained.

## Validation
- `zig build win64` passes (with mandatory binary sanity checks).
- `MTC_DISABLE_PROTON=1 MTC_FRAMES=60 MTC_SEED=1 zig build smoke-win64` passes.

## Important Caveat
To avoid runtime alignment traps in Zig debug safety checks during COM interop, runtime safety is disabled *only* inside D3D11 interop functions in `src/render/d3d11.zig`.

This is acceptable for a feature spike but should be revisited before merging broadly.

## Recommended Follow-up
- Replace ad hoc COM pointer conversions with audited wrappers (or generated wrappers) that satisfy Zig alignment expectations under safety checks.
- Re-enable runtime safety for renderer interop once pointer handling is proven safe.
