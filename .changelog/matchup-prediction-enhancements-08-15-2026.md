# Matchup Prediction Enhancements

Date: 08-15-2026

## Scope Boundary

- Changed: Live matchup prediction loading, matchup-local invalidation, Monte Carlo score generation, and best-two counting probabilities in expanded matchup rosters.
- Not touched: Official scoring results, persisted round schemas, handicap calculations, or series award publication.

## Design Decisions

- Show top-two counting odds beside player names in the existing expanded roster so the matchup header remains compact.
- Derive counting odds from the same simulated scoring-engine results used for win odds, and expose them only for Best 2 per-round scoring where “counts” has an unambiguous outcome-level meaning.
- Model unfinished holes with a regularized normal distribution and a shared round-form component so uncertainty reflects both hole-to-hole variance and correlated good or bad days.

## Deviations

- None.

## Tradeoffs

- Normal-distribution shrinkage is more stable for sparse histories than replaying individual scores, but final accuracy still depends on post-round calibration against a larger completed-matchup data set.

## Open Questions

- Whether a future version should present per-hole contribution share for Best 2 per-hole formats in addition to per-round top-two odds.

## Validation

- Fifteen focused projection, matchup-simulation, and matchup-local invalidation tests passed on iPhone 17 Pro (iOS 26.4) with Address Sanitizer enabled.
- The Sandbox app and unit-test targets compiled successfully; the build reported only pre-existing warnings outside this prediction change.
