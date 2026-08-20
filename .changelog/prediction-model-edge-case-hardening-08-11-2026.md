# Prediction Model Edge-Case Hardening

Date: 08-11-2026

## Scope Boundary

- Changed: Live player projections and matchup-odds eligibility, picked-up-hole behavior, deterministic gross/net scenario generation, historical-sample confidence accounting, and focused regression coverage.
- Not touched: Handicap-posting rules, persisted score schemas, official scoring calculations, or TestFlight distribution.

## Design Decisions

- Use the scoring engine's participant-eligibility policy for prediction inputs so attendance and substitute rules cannot diverge from official matchup scoring.
- Keep unequal active team sizes intact; Best-N remains responsible for selecting the configured number of counting scores from each eligible side.
- Never silently turn an unresolved pickup into a completed stroke-play score. Best-N and Stableford matchup projections may treat it as non-counting, while formats requiring a resolved total report an actionable unavailable state.
- Reuse one deterministic gross scenario stream across Gross and Net views, then apply handicap strokes as the basis-specific transformation.
- Count unique historical observations by source identity rather than unique score/weight combinations or repeated target-hole assignments.

## Deviations

- None.

## Tradeoffs

- A picked-up individual finish remains unavailable until the score is resolved. This favors honest uncertainty over a potentially misleading automatic maximum.

## Open Questions

- Whether a future score-entry schema should distinguish concession, zero-point Stableford pickup, configured maximum, and handicap-posting most-likely score explicitly.

## Validation

- All 11 focused projection and matchup-probability regressions passed across the finalized runs on iPhone 17 Pro (iOS 26.4.1).
- Competition-scope and participant-presence suites passed: 43 tests, including the existing Best-N no-show scoring regression.
- Sandbox app and unit-test targets compiled successfully as part of the Simulator test runs.
