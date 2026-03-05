# Milestone 3 Plan: 3D Staging + Cinematic Readability

Date: March 5, 2026

## Goal

Move from the current 2D semantic overlay to a deterministic, testable 3D presentation that better matches the original artistic concept while preserving the existing arithmetic/event correctness spine.

Milestone 3 focus:
- keep arithmetic and event tape as source of truth;
- elevate scene-state from flat role points to explicit 3D staging;
- introduce deterministic camera choreography;
- preserve automated validation across semantics, layout, and render outputs.

---

## Why This Milestone Now

Current implementation status:
- arithmetic/event pipeline is stable and test-covered (add/sub/shift/mul);
- scene-state is deterministic and inspectable;
- keyframe regression hashes are in place.

Current limitation:
- render output is still essentially 2D billboards/markers;
- depth, camera motion language, and spatial composition are not yet carrying the concept.

Milestone 3 addresses this directly.

---

## Scope (M3)

### 1. 3D Scene-State Extension

Add explicit 3D transform semantics to scene entities without changing arithmetic/event contracts.

Target data additions:
- position: `x, y, z`;
- orientation (at least one deterministic heading/tilt representation);
- scale / size class;
- optional layer/group tag for composition.

Rules:
- scene-state must remain serializable and testable without GPU;
- entity semantic role remains the primary identity;
- no mathematical meaning is moved into shaders.

### 2. 3D Choreography Rules

Introduce deterministic choreography that maps event semantics into spatial motion:
- carry/borrow/shift packets follow deterministic 3D arcs;
- multiplication `partial_row_*` semantics drive explicit row-boundary emphasis in depth;
- settle events converge to stable resting transforms.

Rules:
- deterministic for fixed `(seed, keyframe, sample time)`;
- no wall-clock dependence in choreography paths.

### 3. Deterministic Camera System

Add camera pose as part of scene/choreography output:
- deterministic camera rigs per scene kind and keyframe;
- camera mode examples: column-focus, transfer-follow, final-overview;
- camera constraints that prevent unreadable framing.

Rules:
- camera parameters must be inspectable in CPU-side snapshots;
- camera motion logic must be testable at sample times.

### 4. 3D Render Path Upgrade

Upgrade rendering from flat role quads to simple 3D forms:
- columns/digits rendered as 3D primitives or instanced meshes;
- packet roles rendered as volumetric/solid 3D markers;
- partial row markers rendered as 3D separators/ribbons.

Rules:
- keep deterministic test preset (fixed lights, no temporal effects);
- keep role-based material mapping explicit in CPU-side plan.

### 5. Validation Expansion

Extend tests while preserving current pyramid:
- arithmetic/event tests unchanged and still mandatory;
- scene-state tests expanded with 3D transform/camera assertions;
- keyframe set extended for multiplication storytelling;
- image regression added for selected 3D keyframes under deterministic preset.

---

## Out of Scope (M3)

- physically based cinematic material system;
- post-processing-heavy “trailer” look;
- audio synchronization;
- advanced shadow pipelines not needed for storyboard readability.

---

## Deliverables

1. Scene data model update
- 3D transform fields available in `ArithmeticSceneState` entities;
- camera snapshot included in scene state or adjacent inspectable struct.

2. Choreography implementation
- deterministic 3D motion rules for:
  - addition carry transfer;
  - subtraction borrow transfer;
  - shift transfer;
  - multiplication partial-row emphasis and settle.

3. Render implementation
- 3D primitive rendering path integrated in D3D11 backend;
- deterministic test render preset maintained.

4. Tests
- scene-state tests for 3D transform/camera invariants;
- deterministic sampling tests for transfer vs settle phases;
- updated keyframe baselines including multiplication final/composition frames;
- smoke path still emits deterministic success marker.

5. Documentation
- updated canonical keyframes list;
- deterministic preset settings documented for CI/rebaseline usage.

---

## Acceptance Criteria

M3 is complete only if all are true:

1. `zig build test` passes with new 3D scene/choreography tests.
2. Existing arithmetic/event tests remain green and unchanged in intent.
3. Canonical keyframes include at least one multiplication transfer and one multiplication final 3D frame.
4. Rebaselined semantic/layout/plan hashes are stable under deterministic preset.
5. Win64 smoke path still builds and runs with deterministic output marker in the reference environment.
6. Manual review confirms improved depth legibility and clearer visual hierarchy versus the prior 2D-only staging.

---

## Progress Snapshot (March 5, 2026)

Completed:
- CPU scene-state now carries explicit 3D transforms (`x/y/z`, scale class) and deterministic camera output.
- Multiplication choreography consumes `partial_row_*` semantics and stages row-boundary emphasis.
- D3D11 render path now runs a raymarched fullscreen pass using scene-role instances and camera matrices.
- Raymarch shading includes directional light, soft shadows, AO, bounce, and ground/contact anchoring.
- CPU determinism coverage was expanded with camera-mode and multiplication-focused scene/hash assertions.
- Win64 screenshot keyframe regression pipeline was added:
  - `zig build rebaseline-raymarch-keyframes`
  - `zig build test-raymarch-keyframes`
  - baselines in `docs/RAYMARCH_KEYFRAME_BASELINES.txt`.

In progress:
- Promote milestone status docs/tests to a final M3 acceptance report.

Next:
1. Finalize M3 acceptance/status document with current deterministic test evidence.
2. Run manual visual review pass for the curated 3D keyframes and note any art-direction deltas for M4.

---

## Suggested Implementation Order

1. Add 3D fields to scene entities and update snapshot hashing.
2. Add camera state struct and deterministic camera builder.
3. Update choreography functions to populate 3D transforms/camera.
4. Add/adjust scene-state + sampling tests (CPU-only).
5. Upgrade D3D11 render plan consumption for 3D primitives.
6. Add/refresh keyframes and rebaseline hashes.
7. Run smoke and selected manual visual review.

---

## Risks and Mitigations

Risk: visual upgrade breaks determinism.
- Mitigation: keep deterministic preset mandatory for CI paths and hash baselines.

Risk: rendering work obscures semantic meaning.
- Mitigation: require scene-state assertions for role visibility/position semantics before render changes are accepted.

Risk: too much change in one patch.
- Mitigation: split by layer:
  - scene model;
  - choreography;
  - render plan/backend;
  - keyframes/tests.

---

## Immediate Next Task

Publish the M3 acceptance/status checklist with evidence links (tests, smoke, and raymarch keyframe regression outputs), then close the milestone.
