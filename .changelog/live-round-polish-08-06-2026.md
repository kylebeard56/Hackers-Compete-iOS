# Live Round Polish

Date: 08-06-2026

## Scope Boundary

- Changed: Live-round leaderboard row sizing, live tab icons, and matchup probability precomputation timing.
- Not touched: Matchup probability math, scoring-engine rules, persistence schemas, or the embedded score table layout.

## Design Decisions

- Leaderboard rows return to natural content height instead of retaining the fixed height introduced with the favorite-star removal.
- The live tab strip uses the existing scorecard and crossed-swords glyphs, with the SF Symbol `tablecells` for Table.
- Matchup probabilities begin precomputing after the live-round view model binds and refresh in response to relevant snapshot or score-basis revisions.

## Deviations

- None.

## Tradeoffs

- Probability refreshes are briefly debounced to coalesce rapid score-listener updates while still starting independently of Matchups-tab presentation.

## Open Questions

- None.

## Verification

- Sandbox iOS app target builds successfully.
- `RoundProjectionSimulatorTests` and `MatchupProbabilitySimulatorTests`: 4 passed on iPhone 17 Pro (iOS 26.4.1).
