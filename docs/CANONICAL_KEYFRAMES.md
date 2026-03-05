# Canonical Keyframes

Milestone 2 deterministic semantic/layout/render-plan keyframes are centralized in:

- `src/tests/keyframes.zig`: canonical scene/timestep definitions
- `src/tests/keyframes_baselines.zig`: expected semantic/layout/render-plan hashes

Current canonical set:

1. `add_mid` (`add`, tick `0`, phase `0.5`)
2. `sub_mid` (`sub`, tick `1`, phase `0.4`)
3. `shift_mid` (`shift`, tick `0`, phase `0.5`)
4. `add_final` (`add`, tick `4`, phase `1.0`)
5. `mul_mid` (`mul`, tick `2`, phase `0.5`)
6. `mul_final` (`mul`, tick `4`, phase `1.0`)

## Rebaseline command

To intentionally regenerate baseline hashes:

```bash
zig build rebaseline-keyframes
```

This rewrites `src/tests/keyframes_baselines.zig`.

## Milestone 3 raymarch keyframes

Milestone 3 adds screenshot-based deterministic raymarch checks:

- baseline table: `docs/RAYMARCH_KEYFRAME_BASELINES.txt`
- capture script: `scripts/capture_raymarch_keyframes.sh`
- rebaseline script: `scripts/rebaseline_raymarch_keyframes.sh`
- verification script: `scripts/test_raymarch_keyframes.sh`

Build entrypoints:

```bash
zig build rebaseline-raymarch-keyframes
zig build test-raymarch-keyframes
```

Current curated set:

1. `add_mid_cine`
2. `mul_mid_cine`
3. `mul_final_story`
