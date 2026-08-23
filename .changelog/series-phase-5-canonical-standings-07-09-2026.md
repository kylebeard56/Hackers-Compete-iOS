# Series Phase 5: Canonical Standings

Date: 07-09-2026

## Scope Boundary

- Changed: Opt-in canonical standings reads, complete-generation coverage checks, ordered scoring-average tiebreak projection, round-level tiebreak evidence, and canonical correction identity.
- Not touched: Commissioner policy-authoring UI, automatic historical backfill, destructive migration, or removal of V1 standings documents.

## Design Decisions

- Existing and newly decoded leagues remain on V1 standings unless canonical authority is explicitly enabled.
- Canonical authority is all-or-nothing. Any missing, pending, stale, malformed, or policy-inconsistent completed round falls back to the complete V1 leaderboard.
- A configured tiebreak is applied to a tied-points cohort only when every competitor in that cohort satisfies its minimum-round requirement.
- Historical round values are retained with the comprehensive average so the UI can explain a tiebreak rather than presenting an opaque rank.

## Deviations

None.

## Tradeoffs

- Opted-in leagues perform one additional canonical-results read during core load.
- V1 remains persisted and available as the rollback path while canonical standings are projected in memory.

## Validation

- Sandbox generic iOS build succeeded with `xcodebuild`.
- The complete Phase 0-5 Series regression matrix passed: 259 tests, 0 failures.
- The 24-round, 20-team canonical projection averaged approximately 35 ms in the final simulator run.
- The authenticated Sandbox app launched through XcodeBuildMCP, settled on the dashboard, and was stopped without interaction.
- XcodeBuildMCP's combined build-and-run continues to hit its isolated package-cache failure; native builds, tests, and the plugin launch-only path succeed.
- `git diff --check` passed.

## Open Questions

- Production backfill and commissioner-facing activation remain explicit later-phase rollout work.
