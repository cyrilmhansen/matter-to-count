# Milestone 4 Plan: Visual Language + Review Automation

Date: March 5, 2026

## Goal

Build on Milestone 3's deterministic 3D foundation by improving visual readability and review throughput without weakening arithmetic/event correctness guarantees.

Core M4 intent:
- keep the same layer hierarchy (arithmetic -> events -> choreography -> renderer -> shader enhancement);
- improve role legibility and composition quality across all operations;
- make manual art-direction review repeatable with deterministic capture artifacts.

## Scope (M4)

1. Visual language refinement
- continue role-specific shape/material differentiation;
- improve composition contrast between source/result/packet roles;
- tune camera presets for readability first, style second.

2. Review-pack automation
- deterministic curated screenshot pack for milestone reviews;
- deterministic debug-camera screenshot pack for staging-focused review;
- deterministic depth/role-id debug-pass screenshot pack;
- simple manifest (hash + color diversity) for traceability;
- one build entrypoint for local and CI usage.

3. Validation expansion
- keep M3 regression gates green;
- add at least one additional curated raymarch keyframe if new staging is introduced;
- preserve CPU-side semantic/layout/plan determinism tests.

## Deliverables

1. Build step:
- `zig build m4-review-pack`
- `zig build m4-debug-pack`
- `zig build m4-debug-pass-pack`
- `zig build rebaseline-m4-debug-pass`
- `zig build test-m4-debug-pass`

2. Capture script:
- `scripts/capture_m4_review_pack.sh`
- `scripts/capture_m4_debug_pack.sh`
- `scripts/capture_m4_debug_pass_pack.sh`
  - regression baseline file: `docs/M4_DEBUG_PASS_BASELINES.txt`

3. Documentation:
- this plan document;
- linkage from M3 status/plan to M4 task stream.

## Acceptance Criteria

1. `zig build test` remains green.
2. `zig build test-raymarch-keyframes` remains green.
3. `zig build m4-review-pack` emits deterministic capture pack + manifest.
4. `zig build m4-debug-pack` emits deterministic debug-camera pack + manifest.
5. `zig build m4-debug-pass-pack` emits deterministic depth/role-id pack + manifest.
6. `zig build test-m4-debug-pass` passes against deterministic debug-pass baselines.
7. Manual review can compare storyboard, debug-camera, and debug-pass packs side-by-side.

## Immediate Next Tasks

1. Run first M4 review pack and annotate visual deltas by role.
2. Promote selected M4 debug-pass frames into stricter regression checks once stable.
3. Promote selected M4 review-pack frames into the regression keyframe set once stable.
