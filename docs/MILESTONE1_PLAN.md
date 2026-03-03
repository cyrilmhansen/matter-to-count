# Milestone 1 Plan: Technical Spine + Windows Cross-Run on Linux

Date: March 3, 2026

## Objective
Deliver a deterministic technical spine that proves the project can:
- build as a Windows executable from Linux using Zig;
- initialize Win32 + Direct3D11;
- render a minimal deterministic scene;
- run on Linux via Proton (primary) with Wine fallback;
- exit cleanly after a fixed simulation window for automated smoke checks.

This milestone intentionally excludes arithmetic/event/choreography logic beyond minimal scene placeholders.

## Scope
1. Platform spine
- Win32 app entry + message loop.
- D3D11 device/swapchain creation.
- Resize and clean shutdown handling.

2. Deterministic runtime spine
- Fixed-step simulation clock (`sim_dt`, `sim_frame_index`).
- Frame cap for smoke mode (example: 120 frames).
- Seeded deterministic scene placement.

3. Render spine
- Clear pass.
- Simple geometry draw (triangle first, then instanced primitives).
- Debug metadata print/log per run (seed, frame count, target triple).

4. Linux execution spine
- Cross-compile targets:
  - `x86_64-windows-gnu` (required)
  - `x86-windows-gnu` (optional in M1)
- Execution options:
  - Proton (`proton run app.exe`) preferred when available.
  - Wine fallback (`wine app.exe`) for local automation.

## Out of Scope (M1)
- Arithmetic correctness logic.
- Event tape generation.
- Choreography timeline.
- Keyframe image regression suite.
- Audio sync.

## Repository Layout for M1
Use a minimal subset aligned with `ARCHITECTURE.md`:

- `src/main.zig`
- `src/app/app.zig`
- `src/app/time.zig`
- `src/platform/win32/window.zig`
- `src/render/d3d11.zig`
- `src/scene/scene_state.zig`
- `src/scene/builder.zig`
- `src/util/logging.zig`
- `tests/app/time_test.zig`
- `tests/scene/scene_determinism_test.zig`
- `scripts/run_windows_smoke.sh`

## Build Matrix
Primary build commands to expose in `build.zig`:

1. `zig build test`
- Runs pure deterministic tests (time + scene snapshot).

2. `zig build win64`
- Builds `x86_64-windows-gnu` executable.

3. `zig build win32`
- Builds `x86-windows-gnu` executable (optional pass/fail in M1).

4. `zig build smoke-win64`
- Builds win64 and invokes `scripts/run_windows_smoke.sh`.
- Must return non-zero on runtime failure.

## Proton Strategy
Yes, Proton can be used as the emulator/runtime layer.

Recommended practical approach:
- Prefer Proton for fidelity to DXVK path.
- Keep Wine fallback for CI/local environments without Steam/Proton setup.

Runtime selection order in scripts:
1. `PROTON_BIN` explicitly provided -> use Proton.
2. `proton` found on `PATH` -> use Proton.
3. fallback to `wine`.

Important note:
- Proton is designed for Steam-managed runtime/prefix behavior.
- For deterministic local automation, explicit prefix settings and fixed env are required.

## Environment Contract
Expected environment variables for smoke runs:

- `SMOKE_EXE` (required): absolute path to Windows `.exe`.
- `MTC_FRAMES` (default `120`): fixed frame budget.
- `MTC_SEED` (default `1`): deterministic seed.
- `WINEPREFIX` (recommended): dedicated prefix for the project.
- `PROTON_BIN` (optional): Proton launcher path.

## Smoke Test Contract
The app should support a deterministic non-interactive mode via CLI args:

- `--smoke`
- `--frames <N>`
- `--seed <N>`
- `--headless=false` (still opens device/window for D3D11 validation)

Pass condition:
- Process exits `0`.
- Emits final line `SMOKE_OK frames=<N> seed=<N>`.

Fail condition:
- Non-zero exit or missing success marker.

## Milestone 1 Acceptance Criteria
1. Cross-build: win64 exe produced from Linux with Zig.
2. Runtime: win64 exe launches through Proton on Linux and draws frames.
3. Determinism: same seed and frame budget produce the same scene snapshot hash.
4. Testability: deterministic clock and scene tests pass via `zig build test`.
5. Layering: rendering/platform code remains separate from future arithmetic/event modules.

## Risks and Mitigations
1. Proton path variability
- Mitigation: allow explicit `PROTON_BIN`; print selected runtime.

2. Driver/runtime differences
- Mitigation: keep M1 smoke assertions binary (launch, run N frames, exit cleanly), avoid image strictness in M1.

3. 32-bit target instability
- Mitigation: gate win32 as optional until win64 path is stable.

## Next Step (After M1)
Start Milestone 2 by adding arithmetic + event tape modules with tests, while reusing the deterministic app spine from M1.
