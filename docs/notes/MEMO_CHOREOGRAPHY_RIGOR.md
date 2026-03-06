# Memo on Formalizing the Choreography Layer and Visual Algorithms

**TO:** Matter to Count Development Team and AI Agents
**FROM:** Project Lead
**DATE:** March 6, 2026
**SUBJECT:** Memo on Formalizing the Choreography Layer and Visual Algorithms

## 1. Background and problem statement

During Milestone 3, we observed a friction point between the `Event` layer and the `Scene` layer.
Because the specific visual algorithms, meaning the exact 3D trajectories and timings of numbers, were not mathematically formalized, implementation fell back to ad hoc hardcoded equations such as dumping `@sin(p * pi)` directly inside `event_scene.zig`.

This violates our core principle: **Arithmetic decides, Events describe, Choreography stages.**
When choreography is left vague, it bleeds into scene construction, breaks architectural boundaries, and forces contributors to guess how animation should behave.

To prevent this, the project now treats choreography as a formal contract rather than an informal styling layer.

## 2. Formal motion contract

Every visual operation such as carry, borrow, shift, or settle must be defined as a visual algorithm in `src/choreo/motion.zig`.

A visual algorithm consists of three parts:

1. A normalized time window `p`, derived from event tape logical time and clamped to `0.0 <= p <= 1.0`.
2. An easing function that maps linear time to physical weight.
3. A spatial path equation that defines the motion in terms of `X`, `Y`, `Z`, and rotation over `p`.

Example carry:

* `X(p) = lerp(src_col, dst_col, easeOutCubic(p))`
* `Y(p) = baseline_y + max_height * sin(p * pi)`

## 3. Repository implications

This contract implies the following discipline:

* easing logic belongs in `src/choreo/easing.zig`;
* spatial path logic belongs in `src/choreo/motion.zig`;
* scene builders consume tested motion functions rather than inventing them inline;
* deterministic animation sampling tests must validate representative `p` values for each new motion.

## 4. Motion identities

To preserve visual consistency across scenes:

* **Shift:** mechanical and frictionless, using `easeInOutSine` with no vertical arc.
* **Carry:** energetic and buoyant, using an arcing path with heavy settling behavior.
* **Borrow:** heavy and fracturing, involving lift plus delayed decomposition into lower-order units.

## 5. Guidance for contributors and agents

When implementing a new semantic animation:

1. Define the math first in `src/choreo/motion.zig`.
2. Choose the easing explicitly in `src/choreo/easing.zig` or from its existing catalog.
3. Add deterministic sampling tests for `p = 0.0`, `0.5`, and `1.0` at minimum.
4. Hook the tested motion into `src/scene/event_scene.zig` or the relevant builder only after the motion contract is stable.

Choreography must be treated with the same rigor as arithmetic.
The goal is tunable art direction without sacrificing deterministic structure, testability, or architectural clarity.
