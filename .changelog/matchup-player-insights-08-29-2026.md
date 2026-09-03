# Matchup and Player Insights Refinement

Date: 08-29-2026

## Scope Boundary

- Changed: Round Outcome player detail, Matchup Insights player detail, cumulative scoring visualization, scoring-outcome radar, matchup probability interaction, and finished-match contributor presentation.
- Not touched: Scoring-engine rules, stored round scores, matchup result calculation, or the existing player scorecard table.

## Design Decisions

- Use one shared player-detail presentation so leaderboard and matchup player taps show the same scorecard and analytics.
- Represent matchup probability as one expected-share line around a 50/50 center, assigning half of tie probability to each team while retaining exact team/tie probabilities in the selected checkpoint.
- Treat a tie at the counting cutoff as a shared counting result instead of assigning one tied player an arbitrary zero-percent result.
- Remove completed-match contributor probability bars and place `Counted`, `Tied at cutoff`, or `Not counted` badges in the tappable Players list.

## Deviations

None.

## Tradeoffs

- Finished matchups show final counting status rather than deterministic 100%/0% probability bars; live matchups retain probabilistic counting estimates.
- Projection storage remains relative to par; the player chart converts it to cumulative gross/net strokes at display time so the simulation model remains unchanged.

## Validation

- Sandbox and Production generic iOS builds pass with code signing disabled.
- Focused unit-test sources compile, but simulator execution is blocked before launch by the existing Watch target being embedded as a watchOS device product in the iOS Simulator host.

## Open Questions

None.
