# AGENT

## 1. Purpose

This document defines how contributors and coding agents should work on **Matter to Count**.

The project is both:

* an artistic and visual demo;
* a technical Zig codebase with arithmetic, animation, and rendering layers.

The goal is not only to produce impressive output, but to do so in a way that remains:

* understandable;
* testable;
* incrementally verifiable;
* robust across refactors.

This file establishes the working discipline needed to keep artistic ambition compatible with engineering rigor.

---

## 2. Core rule

At all times, preserve this hierarchy:

1. **Arithmetic decides**
2. **Events describe**
3. **Choreography stages**
4. **Renderer draws**
5. **Shaders enhance**

Do not hide mathematical meaning in ad hoc rendering code.
Do not hide important sequencing logic in shaders.
Do not couple correctness to visual side effects.

If a scene looks beautiful but its meaning is difficult to verify, the implementation is incomplete.

---

## 3. Architecture expectations

The codebase should remain split into layers that can be tested independently.

### Required separations

* arithmetic core;
* event tape generation;
* animation / choreography;
* scene state;
* rendering backend;
* optional audio synchronization.

### Rule

Each layer must be able to fail independently.
A rendering bug must not invalidate arithmetic tests.
A choreography bug must not require shader debugging to understand.

---

## 4. Testing philosophy

This project is visual, but it must not rely on “looks fine to me” as the main validation method.

Testing should happen at several levels.

### 4.1. Test pyramid

Use the following order of confidence:

1. **Pure arithmetic tests**
2. **Event tape tests**
3. **Scene-state tests**
4. **Deterministic animation sampling tests**
5. **Image-based regression tests**
6. **Human visual review for selected milestones**

The lower levels should be cheap, fast, and numerous.
The upper levels should be fewer, more curated, and more stable.

---

## 5. What must be tested automatically

## 5.1. Arithmetic correctness

Every operation implemented in the project must first be validated without any rendering.

Examples:

* addition in bases 2, 8, 10, 16, 60;
* carry propagation;
* subtraction with borrow;
* multiplication by base;
* general multiplication;
* later: division, GCD, square root.

### Expectations

For each operation, test:

* nominal cases;
* edge cases;
* cascade carry / cascade borrow;
* zero handling;
* one-digit and multi-digit cases;
* cross-base invariants where applicable.

### Rule

If arithmetic cannot be trusted, visual output is irrelevant.

---

## 5.2. Event tape correctness

The event tape is the central contract between arithmetic and visuals.
It must be tested directly.

Examples of properties to verify:

* expected number of carry events;
* event order;
* affected columns;
* logical timestamps are monotonic;
* no missing finalization event;
* no impossible event sequences.

### Example

For `17 + 8` in base 10, tests should verify at least:

* one overflow in the units column;
* one carry event to the tens column;
* final result digits equal `25`;
* no extra carry after stabilization.

### Recommendation

Prefer asserting semantic event facts over brittle full-text snapshots.
Structured assertions age better than raw dumps.

---

## 5.3. Scene-state tests

The scene builder should be testable without a GPU.

Given:

* an event tape;
* a time value `t`;
* a deterministic choreography configuration;

the system should be able to produce a scene state that can be inspected in tests.

Examples:

* entity count;
* active column markers;
* visibility flags;
* current transforms;
* current emissive intensity class;
* identity and semantic role of entities.

### Rule

A scene snapshot should be representable as plain data.
If scene state only exists inside draw calls, the architecture is too opaque.

---

## 5.4. Deterministic animation sampling tests

Animation should not be tested only by watching it.

For selected scenes and selected normalized times, sample the animation state and verify:

* object positions;
* interpolation progress;
* whether a carry is in transit or settled;
* whether a borrow packet has expanded;
* whether the camera is in an allowed pose.

### Important

Animation tests require deterministic time and deterministic easing.
No hidden dependence on wall-clock time is allowed.

---

## 5.5. Image regression tests

Yes, it is possible and useful to validate key storyboard images automatically.

However, image tests must be used carefully.
They are best for:

* stable keyframes;
* composition validation;
* layout regressions;
* shader regressions;
* camera regressions;
* obvious lighting mistakes;
* accidental disappearance of objects.

They are not sufficient by themselves to prove mathematical correctness.

---

## 6. Strategy for image-based validation

## 6.1. Golden images for key storyboard frames

Maintain a curated set of **reference frames** for major scenes.

Examples:

* columns emerge;
* addition with carry at peak transfer;
* shift complete;
* decimal-to-binary transition midpoint;
* subtraction borrow expansion;
* multiplication partial rows.

For each reference frame, store:

* scene identifier;
* input operation;
* base;
* deterministic seed;
* camera parameters;
* animation time;
* rendering preset;
* expected image.

### Rule

Golden images must correspond to meaningful conceptual moments, not arbitrary frames.

---

## 6.2. Determinism requirements

Image tests are only useful if rendering is kept sufficiently deterministic.

To improve stability:

* fix the random seed;
* fix viewport size;
* fix camera matrix;
* fix timing inputs;
* disable non-deterministic noise unless seeded;
* avoid frame-to-frame dependence on prior GPU state;
* keep post-processing simple and reproducible.

Absolute bit-for-bit identity may not always be realistic across all drivers.
For local CI and one chosen reference platform, aim for strict consistency.

---

## 6.3. Tolerance strategy

Do not compare images with naive binary equality unless the pipeline is proven fully stable.
Use one or more tolerant metrics such as:

* max per-pixel difference threshold;
* mean absolute error;
* structural similarity style metric;
* masked comparison for known volatile regions.

### Practical recommendation

Use two classes of image checks:

#### Strict mode

For software-generated overlays, masks, IDs, and geometry-debug views.
These should match almost exactly.

#### Perceptual mode

For lit beauty frames.
These should allow tiny numeric differences while still catching meaningful regressions.

---

## 6.4. Multi-render strategy

For some scenes, generate more than one output for tests:

* beauty render;
* semantic ID pass;
* emissive pass;
* depth or occupancy pass;
* debug overlay of columns and anchors.

This helps distinguish:

* logic regression;
* choreography regression;
* lighting regression;
* post-processing regression.

A beauty image alone is often too ambiguous.

---

## 7. Storyboard validation policy

The storyboard should define a set of **validation keyframes**.
Each keyframe should correspond to a concept that must remain legible.

For every such keyframe, define:

* what the viewer should understand;
* which entities must be present;
* which columns must be active;
* where the camera should roughly be;
* whether the image is warm / cold / sparse / dense;
* what kind of event is occurring.

### Example

**Addition with carry — transfer frame**

* viewer should understand overflow and transfer;
* source units column must be saturated;
* one carry entity must be airborne or in transit;
* destination column must be visibly highlighted;
* result digit must not yet be fully settled.

This allows tests to validate both semantics and composition.

---

## 8. Manual review remains necessary

Some qualities are not easy to reduce to metrics.
For milestone scenes, keep manual review for:

* artistic balance;
* pacing;
* emotional readability;
* material quality;
* whether the eye is drawn to the right thing.

Manual review should be the final layer, not the first line of defense.

---

## 9. Recommended repository discipline

## 9.1. Small changes only

Each change should ideally affect one of the following:

* arithmetic logic;
* event schema;
* choreography rules;
* scene generation;
* rendering / shader behavior;
* asset definitions;
* tests.

Avoid large mixed commits that change everything at once.

## 9.2. Every feature should add tests

When a new operation or scene behavior is added:

* add arithmetic tests;
* add event tape tests;
* add at least one scene-state test;
* add a golden image only if the feature is visually mature enough.

Do not add unstable golden images too early.
That only creates noise.

## 9.3. Keep deterministic debug presets

Maintain at least one minimal deterministic render preset designed for tests.

Suggested properties:

* fixed resolution;
* fixed lights;
* no depth-of-field;
* no temporal effects;
* minimal bloom;
* no cinematic camera shake;
* seeded procedural noise only.

Beauty presets and trailer presets may exist separately.

### Camera/framing stability rules

When adjusting renderer framing logic, preserve these constraints:

* do not let volatile entities (transfer packets, active markers, debug tokens) drive camera center/extent;
* prefer smoothing/interpolation of framing over per-frame hard snaps;
* if a view is unstable, validate simulation health first with `MTC_TRACE_ANIM=1` before changing arithmetic or event generation;
* if `tick`/`phase` advance while visuals flicker, treat it as presentation/framing first, not choreography logic failure.

---

## 10. Zig-specific engineering practices

## 10.1. Favor plain data and explicit ownership

Prefer:

* simple structs;
* explicit allocators;
* stable IDs;
* narrow APIs;
* data-oriented scene snapshots.

Avoid hidden ownership and implicit mutation across layers.

## 10.2. Make determinism easy

Avoid tying update logic to actual frame time.
Use explicit simulation time and deterministic stepping.

Prefer APIs like:

* `buildEventTape(...)`
* `buildSceneAtTime(...)`
* `renderScene(...)`

rather than deeply stateful systems that are difficult to replay.

## 10.3. Separate production code from debug inspection tools

Keep optional debug output available:

* event dumps;
* scene dumps;
* camera dumps;
* per-entity summaries;
* render metadata.

These tools are essential for automated validation and for agent-driven development.

## 10.4. Use error sets and assertions deliberately

Use assertions for invariants that should never be broken.
Return errors for expected failure modes.

Examples of invariant violations:

* event timestamps going backwards;
* invalid digit for base;
* carry targeting a non-existent column;
* animation clip referencing a missing entity.

---

## 11. Suggested validation ladder for each new feature

When implementing a new concept, follow this order:

1. write or extend arithmetic tests;
2. implement event generation;
3. add event tape tests;
4. implement scene mapping;
5. add scene-state tests;
6. implement animation;
7. add deterministic time-sampling tests;
8. implement render path;
9. capture one or more golden images;
10. perform manual review.

This order prevents artistic polish from hiding structural bugs.

## 11.5. Implementing a New Visual Algorithm

When an agent is tasked with animating a new semantic event such as a division remainder cascading down, the agent must follow these steps:

1. **Define the math first:** write a standalone function in `src/choreo/motion.zig`, such as `calcRemainderCascade(p: f32, ...)`.
2. **Specify the easing:** decide whether the motion is mechanical, using linear or sine easing, or heavy and organic, using cubic easing.
3. **Write an animation sampling test:** assert that at `p = 0.0` the object is at the source, at `p = 0.5` it is at the expected arc peak or midpoint state, and at `p = 1.0` it is at the destination.
4. **Apply to scene:** only after the math is tested should it be hooked into `src/scene/event_scene.zig` or `builder.zig`.

## 11.6. Implementing Written-Arithmetic Layout

When an agent is implementing or refactoring a paper-like arithmetic scene, the spatial grammar must be explicit before visual polish begins.

1. **Declare row kinds first:** decide which semantic rows exist, such as `carry`, `operand_primary`, `operand_secondary`, `result`, or `partial_product`.
2. **Bind digits to cells:** represent stable digits as occupants of explicit `(row_index, column_index)` cells rather than as free-floating objects.
3. **Stage transfers through anchors:** carry and borrow entities must launch and land through declared transfer anchors rather than being implied by instant digit changes.
4. **Allocate extra rows semantically:** a new multiplication or scratch row should be introduced as a row allocation decision, not as an arbitrary `y` or `z` offset.
5. **Test row semantics directly:** add scene-state assertions that distinguish row identity, active columns, and in-transit packets.

---

## 12. What agents should avoid

Agents working on this codebase should avoid:

* changing arithmetic and rendering in one opaque patch;
* introducing random motion without a seed;
* embedding critical logic inside shader code;
* hardcoding magic animation math inside scene builders, such as `x = x + 0.5 * sin(...)` inside `event_scene.zig`;
* inventing easing logic on the fly instead of routing temporal progress through formalized functions in `src/choreo/easing.zig`;
* guessing written-arithmetic row placement from arbitrary offsets instead of declaring `row_index` and `row_kind`;
* adding unstable snapshot tests without deterministic setup;
* coupling the story meaning to one fragile visual trick;
* replacing readable scene data with implicit GPU-only state;
* using visual approval as a substitute for arithmetic validation.

---

## 13. What agents should actively do

Agents should:

* preserve layer boundaries;
* add deterministic fixtures;
* add representative edge cases;
* keep keyframe tests small and intentional;
* expose enough debug data for machine inspection;
* document assumptions when adding a new visual behavior;
* tune choreography constants in `src/choreo/tuning.zig` rather than scattering literals across scene or renderer code;
* prefer repeatable pipelines over clever one-off effects.

---

## 14. Minimum quality gate before accepting a feature

A feature is not ready unless all of the following are true:

* arithmetic behavior is tested;
* event tape behavior is tested;
* scene state can be inspected;
* animation is deterministic at fixed sample times;
* no obvious image regression appears on selected keyframes;
* the result still serves the storyboard and remains legible.

---

## 15. Final principle

This project is allowed to be poetic.
It is not allowed to be vague.

Beauty is a goal.
Opacity is not.

The code should make it possible to prove, step by step, that each visual event corresponds to a meaningful mathematical transformation.
