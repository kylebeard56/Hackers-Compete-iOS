# Substitute Players

Date: 06-04-2026

## Scope Boundary

- Changed: Series substitute roster role, round-local substitute metadata, scoring eligibility, series round mapping/sync, and key roster/tee-sheet/live-round presentation hooks.
- Not touched: Firestore security rules and backend Cloud Functions.

## Design Decisions

- Treat substitute/alternate as one `substitute` series member role with no permanent series team.
- Store per-round "playing for" context on planned seats and round participants so a substitute can represent different teams in different rounds.
- Default `substitutes_score` to false for legacy leagues.

## Deviations

- None.

## Tradeoffs

- UI propagation is implemented through small shared helpers where possible, while leaving broad visual redesigns out of scope.

## Validation

- Passed generic Sandbox iOS build.
- Passed focused substitute tests for codable defaults, planned-seat/participant metadata, auto tee-group exclusion, represented team mapping, scoring exclusion/inclusion, and best-2 auto-win behavior.
- A broader `ScoringEngineTests` run surfaced `testTeamMatchupAggregateRoundTotalKeepsSelectedStrokeTotals`; the failing aggregate-team-matchup expectation is outside the substitute-specific cases and the substitute tests in that run passed.

## Open Questions

- None.
