# Series Phase 4.5 Hardening

Date: 07-09-2026

## Scope Boundary

- Changed: Canonical processing input identity, durable retry state, scoring-profile revisions, self-describing performance metrics, tiebreak policy contracts, linked-lobby divergence coverage, and Phase 4.5 regression gates.
- Not touched: V1 standings authority, visible leaderboard ordering, production backfill, or tiebreaker authoring UI.

## Design Decisions

- Existing canonical documents remain readable through optional additive fields.
- Scoring profiles referenced by started rounds are copy-on-write; editing creates a new revision for future assignments.
- Canonical publication records a pending processing state before publishing the immutable result and completed pointer.
- Missing processing state on an old completed round does not trigger automatic backfill. Pending, failed, and stale-processor states do retry.
- Tiebreakers are an ordered policy list. Phase 4.5 defines scoring-average semantics without changing current ranking behavior.

## Deviations

- The repository has no Firestore emulator configuration for iOS tests. Phase 4.5 adds deterministic transaction planning and persisted readback comparison gates; emulator process wiring remains separate infrastructure work.

## Tradeoffs

- Pending-state publication adds one write to a newly processed canonical generation in exchange for durable retry discovery.
- Canonical results embed a compact effective-input manifest to make generations auditable and independent of mutable Series documents.

## Validation

- Sandbox generic iOS build succeeded with `xcodebuild`.
- All 248 selected Series regression tests passed, including the 12 Phase 4.5 hardening gates.
- The 20 canonical-result and Phase 4.5 tests passed again after the final pending-state timestamp correction.
- The authenticated Sandbox app launched through XcodeBuildMCP and settled on the dashboard without interaction or a runtime crash.
- XcodeBuildMCP's build-and-run step hit a stale dependency-cache failure after the successful native build; its launch-only path successfully used the installed test build.

## Open Questions

- Decide when to run an explicit commissioner-controlled historical canonical backfill before Phase 5 switches read authority.
