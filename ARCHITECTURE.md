# ARCHITECTURE

## 1. Purpose

**Matter to Count** is a visual and educational arithmetic demo.
It aims to make arithmetic operations visible as physical, luminous, spatial transformations rather than as flat symbolic procedures.

The project sits at the intersection of:

* arithmetic pedagogy;
* visual storytelling;
* low-level graphics programming;
* and disciplined technical design.

Its ambition is twofold:

1. to produce scenes that are visually striking and memorable;
2. to preserve a rigorous internal structure so that each important visual event corresponds to a meaningful mathematical transformation.

This document describes the global technical vision of the project, the main architectural choices, and the engineering principles that should guide implementation.

---

## 2. Project philosophy

### 2.1. Arithmetic first, spectacle second

The project is allowed to be artistic, dramatic, and visually rich.
It is not allowed to become vague.

Every major visual transformation should be traceable to a mathematical idea:

* accumulation;
* overflow;
* carry;
* borrow;
* shift;
* grouping;
* partial products;
* remainder;
* re-expression in another base.

The renderer exists to reveal structure, not to compensate for unclear logic.

### 2.2. Meaning must survive changes in style

The same operation may be shown in different visual worlds:

* historical;
* geometric;
* metallic;
* luminous;
* digital.

These changes in material language should never alter the semantic core of the operation.
The project must therefore separate:

* what the operation means;
* how the operation is staged;
* how the operation is rendered.

### 2.3. Progressive validation is part of the design

Because the project is both artistic and technical, it must support progressive validation.
The intended workflow is not:

* write code;
* render something;
* hope it looks correct.

Instead, the workflow should be:

* prove arithmetic behavior;
* verify semantic events;
* verify scene state;
* verify deterministic animation samples;
* verify selected keyframes;
* then review the result as a visual sequence.

This principle is architectural, not merely procedural.

---

## 3. Design goals

The architecture should support the following goals simultaneously.

### 3.1. Clarity

The project must remain understandable to both developers and future contributors.
The internal model should explain the output.

### 3.2. Separation of concerns

Arithmetic, staging, and rendering must remain distinguishable layers.

### 3.3. Determinism

The project should make deterministic replay, sampling, and testing straightforward.

### 3.4. Incremental development

The project should be buildable in small verified steps.
A scene should be able to exist first as data, then as staging, then as rendering.

### 3.5. Visual expressiveness

The system must leave room for materials, lighting, animation, rhythm, and cinematic composition.

### 3.6. Technical restraint

The project should avoid becoming a general-purpose engine.
It is a focused demo system, not a universal framework.

---

## 4. Scope and recommended implementation order

The project should be developed in a deliberate order based on:

* pedagogical value;
* visual payoff;
* implementation cost;
* reusability of concepts.

### 4.1. Phase 1 — foundational operations

1. **Addition**
2. **Multiplication by the base / shift**
3. **Subtraction with borrow**
4. **General multiplication**

These operations establish the project’s core visual language:

* columns;
* accumulation;
* capacity by base;
* carry transfer;
* borrow transformation;
* positional value;
* repeated structure.

### 4.2. Phase 2 — extended algorithmic operations

5. **Division**
6. **Greatest common divisor**
7. **Square root**

These should only be implemented after the foundational language of the demo is already stable.
They are more procedural, more delicate to stage, and rely on a viewer already understanding the visual grammar.

### 4.3. Initial bases

The initial design should support multiple bases, starting with:

* base 2;
* base 8;
* base 10;
* base 16;
* base 60.

These bases are not just arithmetic parameters.
They also support different visual identities and historical or computational interpretations.

---

## 5. High-level system model

The project should be understood as a pipeline with explicit semantic boundaries.

### Core flow

1. define an arithmetic operation;
2. normalize it into an internal representation;
3. execute the operation in semantic steps;
4. emit an event tape;
5. convert that tape into timed staging instructions;
6. build a scene state for a given time;
7. render that scene;
8. optionally synchronize sound and overlays.

This pipeline is the central mental model of the project.

---

## 6. Architectural layers

## 6.1. Arithmetic layer

### Responsibilities

* represent numbers in a given base;
* represent operations and operands;
* execute arithmetic rules;
* determine carries, borrows, regroupings, shifts, partial products, and other semantic steps;
* compute final results.

### Constraints

* no rendering knowledge;
* no scene knowledge;
* no camera logic;
* no shader assumptions.

### Objective

The arithmetic layer should be correct, testable, deterministic, and compact.
It is the source of truth for mathematical behavior.

---

## 6.2. Event tape layer

The event tape is the formal bridge between arithmetic and presentation.

### Responsibilities

* express what happened semantically;
* preserve order and logical timing;
* identify involved columns, rows, entities, or values;
* remain independent from rendering details.

### Typical event classes

* addition into column;
* column overflow;
* carry emitted;
* carry received;
* borrow requested;
* borrow converted;
* shift applied;
* partial row created;
* result digit settled;
* base transition started;
* base transition completed.

### Objective

The event tape must be stable enough to serve:

* testing;
* choreography;
* debugging;
* later tooling or export.

This is one of the most important abstractions in the whole project.

---

## 6.3. Choreography layer

The choreography layer transforms semantic events into staged temporal behavior.

### Responsibilities

* assign durations and delays;
* define motion arcs and interpolation curves;
* trigger highlights, emphasis, and material reactions;
* coordinate camera constraints and attention;
* schedule optional synchronized sound cues.

### Constraint

The choreography layer must not invent mathematical meaning.
It stages decisions that were already made upstream.

### Objective

This layer should produce animation that feels intentional, readable, and satisfying without breaking semantic clarity.

---

## 6.4. Scene layer

The scene layer holds the inspectable visual state for a given time.

### Responsibilities

* manage entities and their stable IDs;
* manage transforms;
* manage visibility;
* manage current material bindings and emphasis states;
* manage semantic tags useful for debugging and testing;
* expose data for the renderer.

### Objective

The scene layer must exist as data, not only as draw calls.
It should be serializable or at least inspectable enough to support automated tests.

---

## 6.5. Rendering layer

The rendering layer is responsible for drawing the current scene.

### Responsibilities

* upload geometry and instance data;
* evaluate materials and shaders;
* handle lighting;
* perform optional post-processing;
* produce stable debug passes and showcase output.

### Objective

The renderer should be focused, efficient, and visually expressive.
It should remain simple enough that failures can be understood.

---

## 6.6. Optional audio layer

Audio is not required to validate arithmetic, but it is a major multiplier for impact.

### Responsibilities

* map semantic or choreographic events to sound cues;
* keep timing aligned with the same event model as visuals;
* remain optional in early milestones.

### Objective

The audio layer should reinforce the sense that arithmetic has material consequences.

---

## 7. Core architectural rule

At all times, preserve this hierarchy:

1. **Arithmetic decides**
2. **Events describe**
3. **Choreography stages**
4. **Scene stores**
5. **Renderer draws**
6. **Shaders enhance**

If a change makes that hierarchy harder to explain, it is probably architectural debt.

---

## 8. Representation principles

## 8.1. Numbers are structured, not raw strings

Internally, numbers should be represented in terms of:

* base;
* sign if needed;
* digits or units by position;
* explicit column structure;
* optional metadata for staging.

The internal representation should favor correctness and inspectability over presentation convenience.

## 8.2. Visual entities must have stable identities

A carry in transit, a column marker, a result digit, or a borrow packet should have an identity that can be tracked across time.
This is important for:

* animation;
* testing;
* debugging;
* image comparison diagnostics.

## 8.3. Time must be explicit

The system should prefer explicit simulation time over hidden frame-driven mutation.
This enables:

* replay;
* deterministic sampling;
* stable tests;
* easier tooling.

---

## 9. Rendering strategy

## 9.1. Main technical target

The reference rendering stack is:

* **Zig**;
* **Win32**;
* **Direct3D 11**;
* **HLSL**.

### Why this choice

* direct access to a mature Windows graphics API;
* practical interoperability with Zig through C ABI-compatible bindings;
* strong control over the rendering pipeline;
* compatibility path on Linux via DXVK / Proton;
* significantly lower implementation overhead than Vulkan for a project of this scale.

This is a pragmatic choice, not an ideological one.

---

## 9.2. Rendering philosophy

The renderer should favor:

* simple geometry;
* strong composition;
* controlled materials;
* clear lighting;
* restrained post-processing;
* predictable behavior.

The demo does not need complex imported environments or a large content pipeline.
Most scenes can be built from:

* spheres;
* cylinders;
* planes;
* grids;
* simple rails;
* lightweight markers and overlays.

The beauty of the demo should come from staging, timing, materials, and contrast rather than geometric complexity.

---

## 9.3. Instancing and repetition

Many scenes naturally contain repeated elements.
The renderer should take advantage of this using hardware instancing where appropriate.

Typical candidates include:

* beads;
* binary units;
* column markers;
* repeated multiplication cells;
* guides and anchors.

This supports both performance and conceptual cleanliness.

---

## 9.4. Camera as a pedagogical device

The camera is not a decorative free-fly tool.
It is part of the teaching logic.

### Rules

* during critical steps, camera framing must preserve readability;
* orthographic, near-orthographic, or tightly constrained isometric views should be preferred for arithmetic clarity;
* stronger camera movement is acceptable during transitions or emphasis moments;
* the final composition of each keyframe should be deliberately authored.

A visually dramatic camera that obscures the operation is a failure of the system.

---

## 10. Shader policy

Shaders are important, but they must be used with discipline.

## 10.1. Appropriate shader responsibilities

Shaders may handle:

* local lighting;
* emissive glow;
* fresnel-like edge effects;
* reflective or rough material response;
* holographic treatment for digital modes;
* subtle seeded procedural noise;
* highlight and pulse behavior driven by external parameters.

## 10.2. Inappropriate shader responsibilities

Shaders should not be the primary place for:

* arithmetic logic;
* event ordering;
* carry semantics;
* borrow semantics;
* scene-wide state transitions;
* hidden choreography decisions.

### Rule

Shaders should make a clear event more beautiful.
They should not make an unclear event seem impressive.

---

## 11. Visual worlds and semantic stability

The project is expected to move across visual worlds.
Examples include:

* warm historical materials for decimal or sexagesimal scenes;
* colder metallic or luminous materials for binary and hexadecimal scenes;
* transitional scenes where one material language dissolves into another.

These worlds should be treated as **rendering and staging skins** over a stable semantic core.

### Principle

The value should survive the transformation of its representation.
This idea is both pedagogical and architectural.

It implies that base changes and world changes should be modeled explicitly rather than improvised in the renderer.

---

## 12. Testing-informed architecture

The architecture must support the testing strategy defined elsewhere in the project.
This has direct design consequences.

## 12.1. Each layer must be testable independently

At minimum, the architecture should support:

* arithmetic tests;
* event tape tests;
* scene-state tests;
* deterministic animation sampling tests;
* selected keyframe image tests.

## 12.2. Scene state must be inspectable

If an important visual fact cannot be asserted without looking at the beauty render, the architecture is too opaque.

Examples of inspectable facts:

* which column is active;
* whether a carry exists;
* whether a borrow packet has expanded;
* whether a result digit has settled;
* whether the camera is in a valid mode.

## 12.3. Determinism must be designed in

The project should avoid hidden dependency on:

* wall-clock time;
* unseeded randomness;
* prior frame history for core logic;
* uncontrolled camera drift.

Deterministic replay is not only useful for tests.
It is also useful for debugging, tooling, and content iteration.

---

## 13. Production method

The project should be built in small layers of increasing expressiveness.

## 13.1. Recommended feature ladder

For each new operation or major scene behavior:

1. implement arithmetic behavior;
2. validate arithmetic tests;
3. emit semantic events;
4. validate event tests;
5. map events to scene entities;
6. validate scene-state tests;
7. add animation and camera timing;
8. validate deterministic time samples;
9. add rendering polish;
10. capture keyframes and review visually.

This is the practical way to keep the project both artistic and controlled.

## 13.2. Debug-first before beauty-first

For early milestones, provide debug views or simplified passes that make structure obvious.
Examples include:

* semantic ID view;
* column overlay;
* occupancy mask;
* no-postprocess render mode.

Beauty passes should be added on top of validated structure.

---

## 14. Zig engineering principles

The project should follow a style compatible with Zig’s strengths.

### 14.1. Prefer plain data

Use explicit structs, stable IDs, explicit allocators, and narrow APIs.
Avoid hidden ownership and implicit global mutation.

### 14.2. Prefer replayable functions

The system should favor APIs that make the pipeline explicit, for example:

* build operation model;
* build event tape;
* build scene at time;
* render scene.

This is easier to test than opaque mutable update chains.

### 14.3. Keep error handling intentional

Use assertions for true invariants.
Use returned errors for expected failure modes.

### 14.4. Preserve debug visibility

Keep structured inspection tools available:

* event dumps;
* scene summaries;
* camera summaries;
* metadata attached to keyframes.

These are essential for both human and automated work.

---

## 15. What the architecture should avoid

Avoid the following architectural traps:

* turning the project into a generic engine;
* mixing arithmetic and rendering logic in one layer;
* hiding semantic state inside GPU-only code;
* relying on beauty renders as the primary source of truth;
* introducing unstable, non-deterministic cinematic behavior too early;
* importing excessive geometric complexity that adds little pedagogical value;
* making camera motion freer than the math can tolerate.

---

## 16. Milestone structure

A sensible sequence of milestones is:

### Milestone 1 — technical spine

* window creation;
* rendering initialization;
* primitive geometry;
* deterministic timing;
* simple scene draw.

### Milestone 2 — arithmetic core

* number representation;
* addition;
* carry generation;
* semantic event tape.

### Milestone 3 — visible arithmetic

* scene generation;
* carry visualization;
* controlled camera;
* first readable addition sequence.

### Milestone 4 — positional logic

* shift scenes;
* subtraction with borrow;
* stable keyframe tests.

### Milestone 5 — richer composition

* multiplication;
* multiple bases;
* material differentiation;
* transition scenes.

### Milestone 6 — storyboard assembly

* key scenes linked together;
* pacing refinement;
* sound integration;
* milestone review in motion.

This progression keeps the project honest.

---

## 17. Final principle

The architectural goal of **Matter to Count** is not only to make arithmetic look beautiful.
It is to build a system in which beauty emerges from structure.

In practical terms, that means:

* mathematical transformations are explicit;
* visual consequences are staged rather than improvised;
* rendering is expressive but disciplined;
* testing is progressive and meaningful;
* and every major scene remains explainable from the inside.

If this principle is respected, the project can remain simultaneously:

* educational;
* cinematic;
* technically elegant;
* and maintainable enough to grow without losing its soul.
