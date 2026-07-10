# Series Phase 6: Guarded Rollout

Date: 07-09-2026

## Scope Boundary

- Changed: Commissioner policy authoring, historical canonical preparation, verified authority activation, rollback, realtime canonical synchronization, and average-score presentation.
- Not touched: Automatic production migration, removal of legacy standings documents, or unattended background backfill.

## Design Decisions

- Saving a tiebreak policy keeps legacy standings authoritative. Activation is a separate confirmed action.
- Activation regenerates every completed round against an immutable policy revision and switches authority only after the complete projection succeeds.
- Failed or cancelled preparation leaves the visible leaderboard on legacy standings and can be retried.
- General league settings saves cannot overwrite policy revision or standings authority fields managed by the rollout workflow.
- Changing a policy-defining league scoring setting automatically returns standings authority to legacy until a new policy is saved and prepared.

## Deviations

None.

## Tradeoffs

- Canonical leagues add two realtime listeners for processing states and immutable round results so other clients observe activation and later corrections without reloading the Series screen.
- Historical preparation intentionally performs commissioner-triggered writes; it is never started by ordinary app launch or settings reads.

## Open Questions

- Production activation remains a deliberate commissioner action after Sandbox validation.

## Validation

- Phase 6 rollout tests: 8 passed.
- Full Sandbox unit suite: 630 passed, 0 failed, 0 skipped.
- Generic iOS Sandbox build: succeeded.
- XcodeBuildMCP Simulator launch: dashboard settled successfully; no navigation or mutation controls were used.
