# Milestone 2 Plan: Arithmetic Core + Event Tape

Date: March 3, 2026

## Goal
Implement a deterministic arithmetic core and semantic event tape for foundational addition behavior, independent of rendering.

Milestone 2 focus:
- arithmetic correctness first;
- event tape as formal contract;
- tests at arithmetic + event levels.

## Scope (M2)
1. Number representation
- explicit base per value;
- digit validation;
- deterministic digit ordering and normalization.

2. Addition core
- base-aware column addition;
- carry propagation;
- final normalized result.

3. Event tape for addition
- per-column semantic events;
- carry emit/receive events;
- monotonic logical timestamps;
- result finalization event.

4. Tests
- arithmetic tests:
  - `17 + 8 = 25` (base 10)
  - `199 + 7 = 206` with cascade carry
  - binary sample
- event tape tests:
  - expected carry count;
  - monotonic time;
  - finalize event exists.

## Out of Scope (M2)
- scene mapping and choreography integration;
- image regression;
- subtraction/multiplication full support.

## Acceptance Criteria
- `zig build test` passes with arithmetic + event tests.
- `addWithEvents(...)` returns both result and semantic tape.
- event timestamps are monotonic and deterministic.
- no rendering dependency in `src/math` or `src/events`.

## Proposed Next (M2.1)
- add subtraction with borrow using same event contract;
- add explicit fixture format under `tests/fixtures` for later scene-level use.
