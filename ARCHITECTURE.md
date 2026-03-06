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

#### 6.3.1. The Formal Motion Contract

Choreography must never be guessed or hardcoded inline within scene builders.
Every visual operation such as carry, borrow, shift, or settle should be defined as a discrete visual algorithm in `src/choreo/motion.zig`.

A visual algorithm consists of three strict components:

1. **Normalized time window (`p`)** extracted from event tape logical time and mapped to `0.0 <= p <= 1.0`.
2. **Easing function** that converts linear progress into perceived physical weight, such as `easeOutCubic(p)` or `easeInOutSine(p)`.
3. **Spatial path equation** that defines how position and rotation evolve as a function of `p`.

Example carry motion:

* `X(p) = lerp(src_col, dst_col, easeOutCubic(p))`
* `Y(p) = baseline_y + max_height * sin(p * pi)`

#### 6.3.2. The Written Arithmetic Spatial Contract

When the demo stages arithmetic as written work on paper, row and column placement is part of the choreography contract rather than an implementation convenience.

Rules:

* `column_index = 0` is always the least-significant arithmetic column.
* The choreography layer must define a canonical column map such as `X(c) = origin_x + c * column_pitch`.
* If a theme wants a mirrored schoolbook view with units on the right, that mirror must be applied as a presentation transform to the whole layout. It must not redefine event or arithmetic semantics.
* Rows must be explicit semantic bands, not ad hoc `y += 0.5` offsets.
* Every arithmetic row must have both a `row_index` and a `row_kind`.

Canonical row kinds:

* `carry`
* `operand_primary`
* `operand_secondary`
* `result`
* `partial_product`
* `borrow_reserve`
* `annotation`

Each written-arithmetic layout preset must define:

* a monotonic `Y(row_index)` mapping;
* the anchor for a digit cell;
* the anchor for transfer lanes such as carry and borrow;
* the separator line or guide rail positions when the operation uses schoolbook rows.

Using another row on paper is therefore a semantic decision: allocate a new `row_index` with a declared `row_kind` and explicit anchors. It must never be represented only as a renderer-side depth tweak.

#### 6.3.3. Decimal Addition Staging Contract

For schoolbook base-10 addition, the default row order is:

1. carry row
2. upper operand row (`lhs`)
3. lower operand row (`rhs`)
4. result row

The addition choreography must obey the following rules:

* Every visible digit is represented as one stable entity per `(row_index, column_index)` cell.
* Operand digits settle into their cells before the arithmetic transformation beat begins.
* The active column highlight always refers to one logical column across all participating rows.
* The result digit for a processed column settles in the result row of that same column.
* If overflow occurs, the carry must be represented by a transient carry entity with a stable identity from `carry_emit` until `carry_receive`.
* The carry launches from the source column carry anchor, travels through a dedicated carry lane, and lands at the destination column carry anchor before disappearing.
* The receiving column may highlight early, but its settled value must not silently jump before the carry arrival beat.
* Cascade carries must be staged as distinct transfers. They may overlap slightly in timing, but they must remain countable as separate packets.

The intended beat order for a single carry column is:

1. column activates
2. local sum compresses
3. source remainder settles in the result row
4. carry packet emits
5. carry packet lands in the next column
6. destination column settles
7. emphasis releases

#### 6.3.4. Multi-Row Operations and Paper Expansion

Operations that use extra rows, such as long multiplication, must allocate them formally.

Rules:

* Each partial-product row gets its own `row_index` and stays aligned to the same shared column grid as the main operands.
* A shift in multiplication is represented by the row's starting column offset, not by detaching the row from the common grid.
* The final accumulation row is distinct from the temporary partial-product rows.
* Row creation and row completion should be reflected in the event tape, not inferred only from current visibility.
* Camera framing must react to row count through a layout-aware rule rather than scene-local magic numbers.

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

### Runtime framing stability contract

For real-time playback, framing must remain stable even when transient entities appear or disappear.

Rules:

* framing center/extent must be computed from stable semantic entities first (operand/result rows, structural markers);
* volatile helper entities must not drive framing (`active_marker`, token overlays, temporary transfer packets);
* framing should be temporally smoothed rather than hard-snapped each frame;
* storyboard mode favors legibility and stability over aggressive cinematic reframing.

Debugging guidance:

* `MTC_TRACE_ANIM=1` should emit `tick`, `phase`, transit count, and render point count;
* if animation trace advances but visuals still look unstable, classify as renderer/presentation issue before changing arithmetic/choreography logic.

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

## 17. Repository layout

The repository should reflect the architectural layers directly.
It should be easy to find:

* where arithmetic lives;
* where semantic events are defined;
* where scene state is built;
* where rendering begins;
* where tests and golden references are stored.

A possible initial layout is the following.

```text
matter-to-count/
├── build.zig
├── build.zig.zon
├── README.md
├── ARCHITECTURE.md
├── STORYBOARD.md
├── AGENT.md
├── TESTING.md
├── assets/
│   ├── materials/
│   ├── textures/
│   ├── fonts/
│   ├── meshes/
│   ├── audio/
│   └── themes/
├── docs/
│   ├── notes/
│   ├── references/
│   └── captures/
├── src/
│   ├── main.zig
│   ├── app/
│   │   ├── app.zig
│   │   ├── config.zig
│   │   ├── time.zig
│   │   └── modes.zig
│   ├── math/
│   │   ├── number.zig
│   │   ├── base.zig
│   │   ├── operation.zig
│   │   ├── addition.zig
│   │   ├── subtraction.zig
│   │   ├── multiplication.zig
│   │   ├── division.zig
│   │   └── gcd.zig
│   ├── events/
│   │   ├── event.zig
│   │   ├── tape.zig
│   │   ├── builder.zig
│   │   └── dump.zig
│   ├── choreo/
│   │   ├── clip.zig
│   │   ├── timeline.zig
│   │   ├── easing.zig
│   │   ├── motion.zig
│   │   ├── camera_plan.zig
│   │   └── builder.zig
│   ├── scene/
│   │   ├── entity.zig
│   │   ├── transform.zig
│   │   ├── material_ref.zig
│   │   ├── scene_state.zig
│   │   ├── builder.zig
│   │   └── debug_dump.zig
│   ├── render/
│   │   ├── renderer.zig
│   │   ├── device.zig
│   │   ├── shaders.zig
│   │   ├── mesh_pool.zig
│   │   ├── texture_pool.zig
│   │   ├── frame_graph.zig
│   │   ├── debug_passes.zig
│   │   └── postprocess.zig
│   ├── audio/
│   │   ├── cue.zig
│   │   ├── event_audio.zig
│   │   └── mixer.zig
│   ├── theme/
│   │   ├── theme.zig
│   │   ├── decimal_classic.zig
│   │   ├── binary_neon.zig
│   │   └── transition_rules.zig
│   ├── platform/
│   │   ├── win32/
│   │   │   ├── window.zig
│   │   │   ├── d3d11.zig
│   │   │   └── input.zig
│   │   └── common/
│   │       └── platform_time.zig
│   ├── tools/
│   │   ├── render_keyframe.zig
│   │   ├── dump_scene.zig
│   │   ├── dump_events.zig
│   │   └── compare_images.zig
│   └── util/
│       ├── id.zig
│       ├── alloc.zig
│       ├── color.zig
│       ├── math3d.zig
│       └── logging.zig
├── tests/
│   ├── arithmetic/
│   ├── events/
│   ├── scene/
│   ├── animation/
│   ├── render/
│   ├── fixtures/
│   └── golden/
│       ├── debug/
│       ├── beauty/
│       ├── ids/
│       └── occupancy/
└── scripts/
    ├── capture_keyframes.sh
    ├── update_goldens.sh
    └── run_ci_local.sh
```

### Layout principles

* `src/math/` must remain free of rendering concerns.
* `src/events/` defines the canonical semantic contract.
* `src/choreo/` converts semantics into timed behavior.
* `src/scene/` builds inspectable scene data.
* `src/render/` consumes scene data and produces images.
* `src/theme/` contains visual identity choices without redefining arithmetic meaning.
* `src/tools/` exists to support inspection, captures, and regression testing.
* `tests/` mirrors the layered testing strategy.

This layout may evolve, but the layer boundaries should remain recognizable.

---

## 18. Core data model

The project should favor explicit, plain-data structures with stable identities and inspectable state.
The exact Zig syntax may evolve, but the conceptual model should remain close to the following.

## 18.1. Arithmetic model

### Base

A base should be represented explicitly rather than as an unstructured integer passed around everywhere.

Conceptually:

* base value;
* digit range validation;
* optional symbolic alphabet for display purposes.

```text
Base
- radix: u8
- alphabet: []const u8
```

### DigitNumber

A number should be represented structurally.

```text
DigitNumber
- sign: enum { positive, negative }
- base: Base
- digits: []Digit   // usually most-significant to least-significant or vice versa, but consistently
```

Recommended invariants:

* every digit must be valid for the base;
* leading-zero rules should be explicit;
* internal ordering must be consistent across all operations.

### OperationKind

```text
OperationKind
- add
- subtract
- multiply_by_base
- multiply
- divide
- gcd
- sqrt
- base_transition
```

### OperationRequest

```text
OperationRequest
- kind: OperationKind
- lhs: DigitNumber
- rhs: ?DigitNumber
- options: OperationOptions
```

`rhs` may be absent for unary operations or derived transitions.

### ArithmeticStepResult

This represents the semantic output of a single arithmetic step before it becomes a public event.

```text
ArithmeticStepResult
- intermediate_digits
- carries_or_borrows
- affected_columns
- done: bool
```

In practice, the implementation may emit events directly, but this intermediate mental model is useful.

---

## 18.2. Event model

The event tape is the most important shared format in the system.
It should be explicit, compact, and semantically rich.

### EventId

```text
EventId
- value: u64
```

### LogicalTime

Use logical time to order events independently from frame time.

```text
LogicalTime
- tick: u32
- substep: u16
```

### EventKind

```text
EventKind
- column_activate
- digit_place
- column_overflow
- carry_emit
- carry_receive
- borrow_request
- borrow_expand
- digit_settle
- shift_start
- shift_complete
- partial_product_create
- partial_product_settle
- result_finalize
- base_transition_start
- base_transition_midpoint
- base_transition_complete
```

### EventPayload

The payload can be modeled as a tagged union.

```text
Event
- id: EventId
- time: LogicalTime
- kind: EventKind
- subject: SemanticRef
- payload: EventPayload
```

### SemanticRef

This identifies the logical target of an event.

```text
SemanticRef
- column_index: ?u16
- row_index: ?u16
- row_kind: ?PaperRowKind
- digit_index: ?u16
- group_id: ?u32
```

This should not be overloaded with rendering-only references.

### EventTape

```text
EventTape
- operation: OperationRequest
- events: []Event
- final_result: DigitNumber
```

Recommended properties:

* stable ordering;
* monotonic logical time;
* debuggable textual dump;
* deterministic construction.

---

## 18.3. Choreography model

The choreography layer translates semantic events into motion and emphasis.

### ClipId

```text
ClipId
- value: u64
```

### TrackKind

```text
TrackKind
- transform
- emissive
- visibility
- camera
- material_param
- audio_cue
```

### AnimationClip

```text
AnimationClip
- id: ClipId
- target: TargetRef
- track: TrackKind
- start_time: f32
- end_time: f32
- easing: EasingKind
- value_from
- value_to
```

### TargetRef

This identifies what is animated.

```text
TargetRef
- entity_id: ?EntityId
- camera_id: ?CameraId
- cue_id: ?AudioCueId
```

### ChoreographyPlan

```text
ChoreographyPlan
- duration: f32
- clips: []AnimationClip
- camera_plan: CameraPlan
- cue_plan: []AudioCue
```

The choreography plan should be reproducible from the event tape and a chosen theme or staging preset.

### PaperRowKind

```text
PaperRowKind
- carry
- operand_primary
- operand_secondary
- result
- partial_product
- borrow_reserve
- annotation
```

### LayoutAnchorKind

```text
LayoutAnchorKind
- digit_center
- carry_lane
- borrow_lane
- row_guide
```

### WrittenArithmeticLayout

```text
WrittenArithmeticLayout
- origin: Vec3
- column_pitch: f32
- row_pitch: f32
- row_kinds: []PaperRowKind
- cell_anchor(row_index: u16, column_index: u16) -> Vec3
- transfer_anchor(kind: LayoutAnchorKind, row_index: u16, column_index: u16) -> Vec3
```

This structure exists so row allocation, column positions, and transfer lanes are authored as data rather than guessed in scene builders.

---

## 18.4. Scene model

The scene model should be a CPU-side data structure that fully describes the visible state at a given time.

### EntityId

```text
EntityId
- value: u64
```

### EntityKind

```text
EntityKind
- bead
- digit_billboard
- carry_particle
- borrow_packet
- rail
- column_marker
- result_marker
- guide
- light_proxy
- transition_fragment
```

### Transform

```text
Transform
- position: Vec3
- rotation: Quat
- scale: Vec3
```

### MaterialRef

```text
MaterialRef
- theme_material_id: u32
- variant: u16
```

### SemanticTag

This links visual objects back to mathematical meaning.

```text
SemanticTag
- column_index: ?u16
- row_index: ?u16
- row_kind: ?PaperRowKind
- digit_value: ?u8
- role: SemanticRole
```

For written arithmetic scenes, row metadata should be preserved all the way into the scene state so automated tests can distinguish:

* the upper operand row from the result row;
* a carry row from a partial-product row;
* a temporary scratch row from a stable final row.

### SceneEntity

```text
SceneEntity
- id: EntityId
- kind: EntityKind
- transform: Transform
- material: MaterialRef
- visible: bool
- emissive_strength: f32
- semantic: SemanticTag
- instance_group: ?u32
```

### SceneState

```text
SceneState
- time: f32
- entities: []SceneEntity
- lights: []SceneLight
- camera: CameraState
- overlays: []OverlayItem
- metadata: SceneMetadata
```

This structure should be inspectable and, where practical, serializable for debug and tests.

---

## 18.5. Camera model

The camera must be treated as authored state, not just free movement.

### CameraMode

```text
CameraMode
- orthographic_locked
- isometric_locked
- guided_perspective
- transition_orbit
- detail_focus
```

### CameraState

```text
CameraState
- mode: CameraMode
- position: Vec3
- target: Vec3
- up: Vec3
- projection: ProjectionKind
- fov_or_size: f32
```

### CameraPlan

```text
CameraPlan
- keyframes: []CameraKeyframe
- readability_constraints: []CameraConstraint
```

A camera plan should be testable at sampled times.

---

## 18.6. Theme model

Themes should control visual identity while leaving semantics untouched.

### ThemeId

```text
ThemeId
- decimal_classic
- binary_neon
- hexadecimal_glass
- octal_steel
- sexagesimal_bronze
```

### ThemeDefinition

```text
ThemeDefinition
- id: ThemeId
- material_set
- light_profile
- postprocess_profile
- carry_style
- borrow_style
- transition_rules
```

This allows the same event tape to be staged in different material worlds.

---

## 18.7. Render-facing model

The renderer should consume simplified data derived from `SceneState`.

### InstanceData

```text
InstanceData
- world_matrix
- material_index
- emissive_strength
- semantic_color_hint
```

### RenderFrame

```text
RenderFrame
- mesh_batches
- instance_buffers
- light_buffer
- camera_constants
- debug_flags
```

This keeps the renderer focused on drawing rather than interpreting semantics.

---

## 18.8. Motion model (choreography)

### EasingKind

```text
EasingKind
- linear
- ease_in_cubic
- ease_out_cubic
- ease_in_out_sine
```

### MotionPath

```text
MotionPath
- eval(p: f32, src: Transform, dst: Transform) -> Transform
```

---

## 19. Data flow example

A concrete example helps clarify the intended layering.

### Example: `17 + 8` in base 10

#### Arithmetic layer

* input numbers are normalized into `DigitNumber` values;
* the addition is executed column by column;
* the units column overflows;
* the final result is `25`.

#### Event tape layer

The operation emits events such as:

* units column activated;
* digits placed;
* overflow detected in units;
* carry emitted;
* carry received in tens;
* unit digit settled to `5`;
* tens digit settled to `2`;
* result finalized.

#### Choreography layer

The system assigns:

* short timing for digit placement;
* a curved carry arc;
* emissive pulse on carry flight;
* highlight of the receiving tens column;
* a stable camera during the arithmetic moment.

#### Scene layer

At a chosen time sample, scene state may contain:

* visible bead entities for the operands;
* one carry particle in transit;
* one highlighted tens column marker;
* partially settled result glyphs.

#### Rendering layer

The renderer draws:

* marble-like decimal beads;
* warm scene lighting;
* controlled glow on the carry;
* a readable result line.

This example should remain explainable from any layer back to the arithmetic source.

---

## 20. Implementation priorities

The project should be built so that each milestone strengthens both capability and confidence.

### Priority 1

Make arithmetic and event construction trustworthy.

### Priority 2

Make scene state inspectable and replayable.

### Priority 3

Make key transitions visually readable.

### Priority 4

Make rendering expressive.

### Priority 5

Make transitions between visual worlds elegant.

This order matters.
A beautiful but semantically fragile prototype is a trap.

---

## 21. Final principle

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
