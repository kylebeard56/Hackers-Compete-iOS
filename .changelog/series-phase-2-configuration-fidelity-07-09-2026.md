# Series Phase 2: Configuration Fidelity

Date: 07-09-2026

## Scope Boundary

- Changed: Round draft ownership, create/edit persistence mapping, linked-lobby configuration authority, divergence reconciliation, and configuration regression tests.
- Not touched: Standings policies, canonical round results, scoring-average tiebreakers, or Firestore migrations.

## Design Decisions

- One value-semantic `SeriesRoundDraft` owns every persisted field edited by the new/edit round sheets.
- Persistence starts from the original/default `SeriesRoundConfiguration`, then updates exposed fields so hidden and future fields survive an untouched save.
- League defaults seed future rounds only. Existing round snapshots are not dynamically rewritten during sync.
- Series configuration remains authoritative through lobby. Linked changes are represented as divergence and require an explicit Adopt or Reset action.

## Deviations

None.

## Tradeoffs

- Existing sheet layout remains intact in this phase; state ownership and persistence are refactored before visual simplification.
- Divergence is computed from already-loaded linked round roots to avoid adding listener or read fan-out.
- Adopt and Reset are limited to lobby configuration; live and completed round configuration is never reconciled through this UI.

## Validation

- Generic Sandbox iOS build: passed after final review.
- Phase 2 configuration tests: 11 passed, 0 failed.
- Phase 2 plus round-creation mapping tests: 81 passed, 0 failed.
- Combined Phase 0-2 regression suite: 169 passed, 0 failed.
- Large-league standings projection: approximately 3 ms, within the Phase 0 baseline gate.
- Build iOS Apps Sandbox runtime smoke: launched and rendered the dashboard successfully; no write controls used.
- Build iOS Apps isolated builder: package cache could not resolve third-party modules, so compile verification used `xcodebuild` and the plugin launched the already-built Sandbox app.

## Open Questions

- None.
