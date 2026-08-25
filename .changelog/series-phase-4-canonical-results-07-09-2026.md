# Series Phase 4: Canonical Round Results

Date: 07-09-2026

## Scope Boundary

- Changed: Completed-round ingestion generations, canonical result persistence, deterministic source hashing, processing state, and shadow comparison against V1 outputs.
- Not touched: Standings reads, leaderboard ordering, average-score tiebreakers, production migration, or automatic backfill.

## Design Decisions

- Canonical results are additive shadow writes; V1 point-award, handicap, and standings publication remains authoritative in this phase.
- A deterministic generation key combines source revision, policy fingerprint, and processor version.
- Retries of the same generation are no-ops. A score correction changes the source revision and creates a new auditable generation.
- The immutable result and latest processing-state pointer publish in one Firestore transaction. A retry is read-only, and an older source timestamp cannot replace a newer generation even when two clients finish out of order.
- Automatic award generation and canonical performance metrics reuse the same primary `ScoringResult`; timestamp-only V1 publication fields are excluded from the semantic projection.

## Deviations

None.

## Tradeoffs

- Canonical documents initially embed projections already computed by the V1 pipeline. Phase 5 can switch standings reads only after shadow comparisons are proven.
- Historical generations are retained for auditability rather than overwritten.

## Validation

- Generic iOS Sandbox build succeeded.
- Simulator test build succeeded on iPhone 17 Pro, iOS 26.4.1.
- Phase 0-4 regression suite: 49 tests passed with zero failures before the final transaction hardening.
- Final Phase 4 gate: 8 tests passed with zero failures after transaction hardening.
- Canonical generation benchmark: 100 SHA-256 generation keys averaged approximately 14 ms in the final simulator run.
- Read-only Sandbox smoke launch succeeded and rendered the dashboard. No round or league data was created or edited.

## Open Questions

- None.
