# Series Phase 7: Migration And Rollout

Date: 07-10-2026

## Scope Boundary

- Changed: Read-only migration assessment, resumable bounded preparation, dual-read standings comparison, guarded activation, and commissioner-visible migration status.
- Not touched: Automatic production migration, destructive legacy cleanup, or server-authoritative Firebase ingestion.

## Design Decisions

- Existing immutable processing-state pointers are the durable migration checkpoint; no separate mutable migration document is introduced.
- Preparation runs in explicit batches and never activates standings in the same operation.
- Activation requires complete canonical coverage and semantic agreement between persisted V1 standings and the unfiltered canonical award baseline.
- Policy-driven exclusions and tiebreak ordering changes are reported separately from unexplained award drift.
- New leagues remain legacy-authoritative until their course, scoring contract, and standings policy are explicitly configured; there is no safe policy to auto-activate at league creation time.

## Deviations

- Firebase Function ingestion remains deferred until representative production leagues complete shadow comparison and rollback rehearsal.
- The original new-league-first switch is represented by the per-Series activation gate instead of a default-on flag, preserving legacy decoding and incomplete new-league setup flows.

## Tradeoffs

- A readiness check explicitly reloads completed-round snapshots to detect stale source generations. This work occurs only after a commissioner requests it, never during ordinary Series loading.

## Open Questions

- Commissioner production signoff and a server-ingestion cutover remain operational follow-ups after this client release is deployed.

## Validation

- Phase 7 migration tests: 8 passed.
- Combined Phase 6-7 continuity gate: 16 passed.
- Full Sandbox unit suite: 638 passed, 0 failed, 0 skipped.
- Generic iOS Sandbox build: succeeded; Phase 7 files emitted no warnings.
- XcodeBuildMCP launch-only smoke: app process launched and stopped successfully without interaction or data writes. An Apple Account Verification system overlay prevented dashboard inspection.
- XcodeBuildMCP combined build-and-run remained silent and was terminated; native Xcode compilation and tests completed successfully.
