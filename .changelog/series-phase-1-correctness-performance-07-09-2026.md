# Series Phase 1: Correctness And Immediate Performance

Date: 07-09-2026

## Scope Boundary

- Changed: Added a concurrent snapshot repository, semantic award and standings diffs, atomic batch publication, shared critical reads, one standings materialization per refresh, and async collection mutation safeguards.
- Not touched: Firestore document schemas, scoring formats, standings sort rules, configurable tiebreakers, or user-facing Series controls.

## Design Decisions

- A linked-round snapshot succeeds only when all seven independent components load successfully.
- Bulk snapshot work is bounded to three rounds by default while each round fans out its component reads.
- Automatic awards and standings publish only from authoritative reads; an error is distinct from an empty collection.
- Equivalent derived rows retain persisted timestamps and skip writes.
- Replacement batches fail before writing above Firestore's 500-operation limit.
- One rebuild timestamp is shared by every computed standings row to avoid repeated clock conversion in the aggregation hot loop.

## Backward Compatibility

- No data migration is required.
- Existing Firebase array-returning reads remain available, while critical publication paths use result-returning variants.
- Phase 0 fixtures continue to define scoring and ranking output.

## Validation

- Sandbox generic iOS build succeeded.
- Phase 1 pipeline suite passed 11 tests with zero failures.
- Combined Phase 0, Phase 1, and existing Series regression gate passed 168 tests with zero failures after all edits.
- The 640-award projection improved from the Phase 0 166 ms observation to about 3.0 ms across five isolated measurements.
- Build iOS Apps could inspect and drive the simulator, but its isolated build workspace could not resolve the repository's cached Swift packages; compilation and tests used the normal Xcode package cache.

## Tradeoffs

- Atomic replacement is deliberately capped at 500 operations until a generation-based publication schema can make larger updates all-or-nothing.
- Snapshot caching is in-memory and invalidation-driven; durable derived snapshots remain a later-phase concern.

## Open Questions

- Define the future generation schema before supporting standings publications larger than one Firestore batch.
- Add configurable scoring-average tiebreakers only after their inputs and compatibility rules are represented explicitly in the Series configuration model.
