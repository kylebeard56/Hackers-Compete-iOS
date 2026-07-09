# Series Phase 0 Baseline

Date: 07-09-2026

## Scope Boundary

- Changed: Added Series performance diagnostics, reusable configuration and award fixtures, golden standings tests, a large projection benchmark, and a durable baseline document.
- Not touched: Series scoring rules, award calculations, Firestore schemas, standings output, linked-round sync decisions, and user-facing UI.

## Design Decisions

- Diagnostics use bounded in-memory samples and unified logging instead of analytics events or a debug UI.
- Logical reads and writes represent repository operations at an instrumented boundary, not billed Firestore document counts.
- The production standings comparator is now an internal static function so golden tests exercise the same comparator used by the app.
- Performance tests remain observational until enough Phase 0 samples exist to establish reliable budgets.

## Deviations

- No Firebase emulator benchmark was added in this phase; runtime repository diagnostics cover live integration paths while deterministic unit fixtures lock computation behavior.

## Tradeoffs

- Instrumentation adds a small bounded memory and unified-log cost in exchange for comparable measurements during later phases.
- Series and competitor identifiers are retained in-process for diagnostics but marked private in unified logs.
- Existing sequential snapshot loading is measured but intentionally unchanged until Phase 1.

## Validation

- Sandbox app build succeeded.
- All 5 Phase 0 behavior and performance tests passed.
- All 82 existing Series Codable, award aggregation, and round sync tests passed.
- Initial large-fixture clock average was 166 ms with 2.96% relative standard deviation under Address Sanitizer.

## Open Questions

- Set CI performance thresholds after collecting stable local and CI benchmark variance.
