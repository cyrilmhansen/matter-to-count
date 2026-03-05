# Milestone 3 Status: 3D Staging + Cinematic Readability

Date: March 5, 2026

## Scope summary

Milestone 3 targeted:
- deterministic 3D scene-state and camera output;
- semantic choreography mapped into readable 3D staging;
- upgraded 3D render path (raymarched primitives) without breaking arithmetic/event correctness;
- expanded deterministic regression coverage.

## Acceptance checklist

1. `zig build test` passes with 3D/choreography assertions.
- Status: Done

2. Arithmetic/event tests remain green and unchanged in intent.
- Status: Done

3. Canonical keyframes include multiplication transfer/final coverage.
- Status: Done (`mul_mid`, `mul_final` in canonical CPU keyframe set)

4. Deterministic baseline regressions are stable.
- Status: Done
- CPU hashes: `zig build rebaseline-keyframes` / `zig build test`
- Raymarch screenshot hashes: `zig build rebaseline-raymarch-keyframes` / `zig build test-raymarch-keyframes`

5. Win64 smoke path still builds/runs deterministically.
- Status: Done (`zig build win64`, smoke/test scripts green in reference env)

6. Manual review confirms improved depth/hierarchy.
- Status: Pending final artistic sign-off (engineering gates are green)

## Regression assets

- CPU keyframe baselines:
  - `src/tests/keyframes_baselines.zig`
- Raymarch keyframe baselines:
  - `docs/RAYMARCH_KEYFRAME_BASELINES.txt`
  - curated IDs: `add_mid_cine`, `sub_mid_story`, `shift_mid_cine`, `mul_mid_cine`, `mul_final_story`

## Outcome

Milestone 3 engineering deliverables are complete and gated by deterministic tests.
Remaining closure item is manual artistic review/sign-off.
