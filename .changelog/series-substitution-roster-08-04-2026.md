# Series Substitution Roster

Date: 08-04-2026

## Scope Boundary

- Changed: Series tee-sheet normalization, round participant selection, substitution propagation, lobby reconciliation, and focused regression coverage.
- Not touched: Firestore document schemas, bulk data migration, or automatic mutation of live, paused, completed, and archived rounds.

## Design Decisions

- Treat the planned tee sheet as the authoritative Series-owned roster and represent a substitute as a one-for-one alias of the replaced member.
- Heal legacy planned data through the normal planning and lobby reconciliation paths instead of adding a backend migration.
- Preserve non-Series lobby participants during attendance and lazy lobby repair.

## Deviations

- None.

## Tradeoffs

- Repair is lazy and deterministic, so historical live/completed rounds remain immutable while planned rounds and unscored lobbies self-heal when reconciled.

## Open Questions

- None.

## Validation

- Focused Series round creation and sync suites: 130 tests passed.
- Broader Series V2, configuration, policy, Codable, handicap-accrual, and scoring-engine suites passed.
- Full Sandbox generic iOS device build passed.
- Scoped `git diff --check` passed.
