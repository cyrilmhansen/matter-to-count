# TESTING

## 1. Purpose

This document defines the testing strategy for **Matter to Count**.

The project is visual, animated, and artistic, but it must still support progressive and mostly automatic validation.
The objective is to detect regressions early without reducing the project to a narrow set of brittle checks.

Testing must answer five different questions:

1. **Is the arithmetic correct?**
2. **Is the arithmetic translated into the right sequence of semantic events?**
3. **Does the scene state correctly represent those events at a given time?**
4. **Does the renderer still produce the expected key visual structures?**
5. **Does the resulting sequence remain readable and faithful to the storyboard?**

No single test type can answer all five.
The project must therefore rely on a layered validation strategy.

---

## 2. Testing principles

### 2.1. Prefer proof over impression

A frame that looks good is not sufficient evidence that the system is correct.
A mathematically correct implementation may still produce unreadable staging.
Both dimensions must be tested.

### 2.2. Validate meaning before appearance

Lower layers must be validated before visual polish is trusted.
The recommended order is:

1. arithmetic;
2. event tape;
3. scene state;
4. animation sampling;
5. render output;
6. human review.

### 2.3. Keep tests deterministic whenever possible

Tests should not depend on wall-clock timing, random noise without a fixed seed, camera drift, or unstable rendering presets.
The more deterministic the pipeline is, the more useful the test suite becomes.

### 2.4. Test the contract between layers

The central contract of the project is not the final frame.
It is the transition:

**arithmetic -> semantic events -> scene state -> rendered image**

Each boundary must be testable independently.

---

## 3. Test pyramid

The project uses the following test pyramid.

### Level 1 — Arithmetic tests
Fast, numerous, mandatory.
These validate arithmetic logic independently from rendering.

### Level 2 — Event tape tests
Fast, semantic, mandatory.
These validate that operations produce the right sequence of events.

### Level 3 — Scene-state tests
Moderate cost, mandatory for major features.
These validate that the event tape is mapped to the expected entities and logical scene configuration.

### Level 4 — Deterministic animation sampling tests
Moderate cost, recommended.
These validate selected moments in time for key animations.

### Level 5 — Image regression tests
More expensive, curated, limited in number.
These validate keyframes and important visual structures.

### Level 6 — Human review
Manual, milestone-based.
This validates pacing, artistic balance, and conceptual readability.

The lower the level, the more tests there should be.
The higher the level, the more selective and stable the test cases must be.

---

## 4. Test categories

## 4.1. Arithmetic tests

Arithmetic tests must cover all implemented operations independently from the renderer.

### Initial scope
- addition;
- carry propagation;
- subtraction with borrow;
- multiplication by the base / shift;
- general multiplication.

### Extended scope
- division;
- greatest common divisor;
- square root.

### Coverage expectations
For each operation, test:
- typical cases;
- minimal inputs;
- zero behavior;
- single-column behavior;
- multi-column behavior;
- cascade carry / cascade borrow;
- edge conditions per base;
- correctness across bases when applicable.

### Numeric scope (current)
- Arithmetic fixtures and operation tests are currently validated for values representable in `u64`.
- This limit is intentional for the current milestone to keep arithmetic/event/scene iteration fast and deterministic.
- Expanding beyond `u64` is deferred until product needs require larger ranges.

### Examples
- `17 + 8` in base 10 produces `25` with one carry;
- `199 + 7` in base 10 produces `206` with cascade carry;
- `52 - 7` in base 10 produces `45` with borrow;
- `1011 + 0011` in base 2 produces `1110`;
- shifting left by one position in base 2 multiplies by 2;
- shifting left by one position in base 10 multiplies by 10.

### Recommended style
Arithmetic tests should assert:
- input values;
- base;
- exact output digits;
- exact carry / borrow count when relevant.

These tests should be written first.

---

## 4.2. Event tape tests

The event tape is the semantic bridge between math and visuals.
It must be tested directly.

### Purpose
Verify that arithmetic is expressed through the correct sequence of semantic events.

### Typical event assertions
- event count;
- event order;
- column indices;
- logical timestamps are monotonic;
- carry originates from the correct column;
- borrow targets the correct source column;
- shift affects the expected entities or columns;
- finalization event is present.

### Examples
For `17 + 8` in base 10, event tape tests should verify:
- the units column receives both values;
- an overflow event occurs in units;
- one carry is emitted to tens;
- the result stabilizes as `25`.

For `52 - 7` in base 10, tests should verify:
- a borrow request is triggered from tens;
- one higher-order unit is transformed into ten lower-order units;
- the subtraction resolves to `45`.

### Recommended style
Prefer structured assertions on event properties rather than full raw text snapshots.
If snapshots are used, they should be supplemental, not primary.

---

## 4.3. Scene-state tests

Scene-state tests validate the CPU-side representation of the scene at a specific time.
These tests should not require a GPU.

### Purpose
Verify that the semantic event sequence is correctly mapped to visible entities and logical visual state.

### What should be testable
- entity count;
- entity types;
- visibility state;
- semantic role of entities;
- column markers;
- current transforms;
- current highlight state;
- current emissive class or intensity bucket;
- active result line;
- current camera mode or camera constraint state.

### Examples
At a time where a carry is in transit, tests may assert:
- one carry entity exists;
- it is visible;
- it is not yet settled;
- source units column is resolved;
- destination tens column is marked as receiving.

At a time where a borrow packet is expanding, tests may assert:
- one borrow source entity has been consumed;
- ten lower-order entities are present or represented logically;
- the target column is flagged as replenished.

### Requirement
The scene builder must expose a serializable or inspectable scene snapshot format.
If the scene only exists implicitly in renderer state, testing is insufficiently supported.

---

## 4.4. Animation sampling tests

Animation must be testable at deterministic times.

### Purpose
Verify that transitions are correct, not only start and end states.

### Requirements
- explicit simulation time;
- deterministic easing functions;
- no dependence on real frame rate;
- no hidden time accumulation.

### Typical assertions
At time `t`, verify:
- entity position;
- interpolation progress;
- whether a carry is airborne or settled;
- whether the camera is within allowed bounds;
- whether the destination column is highlighted;
- whether post-transition stabilization has happened.

### Example
For a carry arc, sample at:
- `t0` = before lift;
- `t1` = mid-flight;
- `t2` = landing;
- `t3` = post-settle.

Each sample should have a small set of semantic assertions.

---

## 4.5. Image regression tests

Image regression tests validate visual output for carefully selected keyframes.

### Purpose
Catch regressions in:
- composition;
- camera framing;
- entity disappearance;
- obvious lighting changes;
- shader changes;
- accidental layout shifts;
- transition staging.

### Important limitation
Image tests do not prove arithmetic correctness.
They only validate visible consequences of deeper layers.

### Recommended scope
Use image tests only for:
- stable scenes;
- major storyboard moments;
- debug views;
- mature features.

Do not create large numbers of fragile image snapshots during early experimentation.

---

## 5. Storyboard keyframe validation

The storyboard should define a subset of **validation keyframes**.
These are conceptually meaningful moments that must remain legible over time.

### Recommended initial keyframes
1. **Columns emerge**
2. **Addition with carry — transfer moment**
3. **Cascade carry — propagation moment**
4. **Shift complete**
5. **Decimal to binary transition midpoint**
6. **Binary addition with active carry**
7. **Borrow expansion moment**
8. **Multiplication with visible partial rows**
9. **Final tableau**

### For each validation keyframe, define
- scene identifier;
- input operation;
- base;
- deterministic seed;
- simulation time;
- camera preset;
- render preset;
- expected semantic conditions;
- expected output image(s).

### Example keyframe spec
**Keyframe:** addition-carry-transfer
- operation: `17 + 8`
- base: 10
- time: mid-flight carry
- expectation:
  - one carry entity in transit;
  - units column resolved to remainder;
  - tens column marked as receiving;
  - camera remains readable;
  - warm material palette active.

This should support both data-level checks and image-level checks.

---

## 6. Determinism requirements

A testable visual pipeline requires deterministic inputs.

### Must be fixed in automated tests
- viewport size;
- render scale;
- camera preset;
- simulation time;
- random seed;
- asset revision;
- shader variant;
- render preset;
- input operation;
- base.

### Strongly recommended
- stable light list;
- stable material parameters;
- no camera shake;
- no depth-of-field in test presets;
- no temporal accumulation effects;
- seeded procedural noise only.

### Separate presets
Maintain at least two render presets:

#### Test preset
Designed for reproducibility.
Minimal post-processing.
Stable lighting.
High readability.

#### Beauty preset
Designed for showcase output.
May include stronger bloom, richer materials, and more cinematic presentation.
Not suitable as the only automated baseline.

---

## 7. Image comparison strategy

## 7.1. Comparison modes

Use two main classes of comparisons.

### Strict comparison
Use for:
- debug overlays;
- semantic ID buffers;
- occupancy masks;
- column guides;
- deterministic UI overlays.

These outputs should be nearly exact.

### Perceptual comparison
Use for:
- beauty renders;
- lit scenes;
- emissive materials;
- bloom or soft post-processing.

These outputs should tolerate tiny numerical differences while still catching meaningful regressions.

---

## 7.2. Suggested auxiliary render passes

For image-based validation, produce more than one output when useful.

Recommended passes:
- beauty pass;
- semantic ID pass;
- emissive pass;
- occupancy or mask pass;
- optional depth pass;
- optional debug composition overlay.

### Why this matters
A beauty-frame failure may be ambiguous.
An ID pass or occupancy pass can reveal whether the root problem is:
- missing geometry;
- wrong entity mapping;
- camera shift;
- lighting only;
- post-processing only.

---

## 7.3. Failure diagnostics

When an image test fails, the test tooling should ideally emit:
- actual image;
- expected image;
- diff image;
- metadata dump;
- scene snapshot summary.

This reduces time spent guessing whether the failure is meaningful.

---

## 8. Human review policy

Some qualities are still best judged by a human.

### Human review is recommended for
- major storyboard milestones;
- large visual refactors;
- changes to camera language;
- material redesigns;
- final timing and pacing decisions.

### Review questions
- Is the operation still readable?
- Is the eye guided to the correct event?
- Has the scene become busier without becoming clearer?
- Does the visual style still support the mathematical idea?
- Does the sequence still match the intended emotional rhythm?

Manual review should confirm and refine, not replace automated validation.

---

## 9. Validation ladder for new features

Every new feature should follow the same validation ladder.

### Step 1 — Arithmetic
Add or update arithmetic tests.

### Step 2 — Event tape
Add or update semantic event tests.

### Step 3 — Scene-state
Add or update scene-state tests.

### Step 4 — Animation sampling
Add deterministic time-sampling tests for important transition moments.

### Step 5 — Rendering
Add or update render tests only when the feature is visually mature enough.

### Step 6 — Human review
Review the feature in motion, not only as still frames.

This order reduces the risk of compensating for logic errors with visual polish.

---

## 10. Suggested fixture strategy

Fixtures should be small, explicit, and reusable.

### Recommended fixture fields
- operation type;
- operands;
- base;
- visual theme;
- camera preset;
- seed;
- normalized time or absolute scene time;
- render preset.

### Example fixture categories
- `addition/simple_no_carry`
- `addition/decimal_single_carry`
- `addition/decimal_cascade_carry`
- `subtraction/borrow_once`
- `shift/binary_left_once`
- `transition/decimal_to_binary`
- `multiplication/partial_rows`

### Rule
Fixtures should describe intent clearly.
Avoid cryptic fixture names.

---

## 11. Continuous integration strategy

The test suite should be split by cost.

### Fast CI (every commit)
Run:
- arithmetic tests;
- event tape tests;
- scene-state tests;
- selected animation sampling tests.

### Medium CI (main branch or pull requests)
Run:
- deterministic render tests for debug views;
- limited keyframe image regression tests.

### Heavy validation (nightly or milestone)
Run:
- full storyboard keyframe set;
- beauty-frame comparisons;
- artifact generation for manual review.

Current deterministic review-pack entrypoint:

```bash
zig build m4-review-pack
```

This writes a curated screenshot set and manifest to `/tmp/mtc_m4_review_pack`.

Debug-camera companion pack:

```bash
zig build m4-debug-pack
```

This writes a curated screenshot set and manifest to `/tmp/mtc_m4_debug_pack`.

Shader debug-pass companion pack (depth + role IDs):

```bash
zig build m4-debug-pass-pack
```

This writes a curated screenshot set and manifest to `/tmp/mtc_m4_debug_pass_pack`.

To baseline and verify deterministic debug-pass outputs:

```bash
zig build rebaseline-m4-debug-pass
zig build test-m4-debug-pass
```

This prevents visual tests from slowing down everyday iteration too much.

---

## 12. Repository conventions for tests

Recommended high-level layout:

- `tests/arithmetic/`
- `tests/events/`
- `tests/scene/`
- `tests/animation/`
- `tests/render/`
- `tests/fixtures/`
- `tests/golden/`
- `tools/render_keyframe/`
- `tools/diff_images/`

### Suggested substructure for golden data
- `tests/golden/debug/`
- `tests/golden/beauty/`
- `tests/golden/ids/`
- `tests/golden/occupancy/`

Keep debug baselines separate from beauty baselines.

---

## 13. Acceptance criteria by feature maturity

## 13.1. Experimental feature
Allowed:
- arithmetic tests only;
- event tape tests;
- no image baselines yet.

## 13.2. Feature entering MVP
Required:
- arithmetic tests;
- event tape tests;
- scene-state tests;
- at least one animation sample test.

## 13.3. Visually stable feature
Required:
- at least one golden keyframe;
- debug pass validation;
- human review.

## 13.4. Storyboard-critical feature
Required:
- data-level validation;
- deterministic keyframe tests;
- diff outputs on failure;
- milestone review in motion.

---

## 14. Anti-patterns

Avoid the following:
- trusting only beauty renders;
- using image tests without fixed seeds and presets;
- storing random arbitrary snapshots as golden images;
- merging arithmetic, choreography, and shader changes in one opaque patch;
- hiding semantic state in GPU-only logic;
- relying on visual approval instead of structural assertions;
- allowing cinematic effects to break readability in test presets.

---

## 15. Minimum quality gate

A feature should not be considered complete unless:
- arithmetic behavior is correct and tested;
- event tape behavior is correct and tested;
- scene state can be inspected and tested;
- key transition times are deterministic;
- no critical image regression appears on selected keyframes;
- the feature still supports storyboard readability.

---

## 16. Final rule

Testing in this project is not opposed to artistic ambition.
It is what makes artistic ambition sustainable.

The objective is not to freeze the visual language too early.
The objective is to make every important visual decision traceable to a meaningful and verifiable mathematical event.
