# Live-Round Continuity and Analytics

Date: 08-05-2026

## Scope Boundary

- Changed: Live leaderboard handicap context, persisted round restoration, series handicap trend, canonical prediction samples, player projections, completed-round pace and outcome analytics, in-round handicap-stroke usage, and matchup probabilities.
- Not touched: Cross-series prediction history, custom/non-stroke prediction approximations, or reopening transient sheets after restoration.

## Design Decisions

- Preserve the handicap allowance frozen when the round was created and present it adaptively in the leaderboard.
- Restore only durable round context: destination, selected hole, and selected live-round tab.
- Keep prediction computation deterministic, off the main actor, and independent of Firebase and SwiftUI.
- Make player and matchup prediction surfaces available automatically for supported rounds; they are not feature flagged.
- Use Firebase Remote Config, rather than PostHog, for future product feature flags.
- Run every supported matchup simulation through the production `ScoringEngine` so team aggregation, best-N, match play, normalization, and handicap allocation cannot drift from the live result.
- Show a completed player's actual cumulative score against a dotted round-average pace line, where below pace is hot and above pace is cold.
- Adapt Box Fox's layered radar treatment for the six gross scoring outcomes, with a continuous green-to-purple-to-system-error gradient and a complete VoiceOver count summary.
- Split frozen handicap allocation into strokes already consumed and strokes remaining, with the remaining stroke holes listed during a live round.

## Deviations

- None.

## Tradeoffs

- Handicap history is recomputed with the current series rules, so the chart explains today’s index model rather than preserving historical configuration snapshots.
- Prediction history is intentionally limited to the active series to keep the first model explainable and auditable.

## Rollout Guardrails

- Player projections remain measurable against the hole-three holdout target of placing 70–90% of finishes inside the displayed 80% interval.
- Matchup probabilities remain measurable against a multiclass Brier score no worse than the handicap-only baseline.
- Custom and shared-score formats surface an explicit unsupported state instead of an inferred probability.
- Matchup scenarios are evaluated off the main actor across a bounded worker pool; a 100-scenario best-2-of-4 scoring-engine fixture completes in 0.45 seconds under the simulator’s debug/Address Sanitizer test configuration.

## Verification

- Sandbox app build succeeds.
- Full `HackersUnitTests` run on iPhone 17 Pro / iOS 26.4.1 Simulator: 705 passed, 0 failed, 0 skipped.
- Coverage includes deterministic simulation, Gross/Net parity, confidence, best-2-of-4 matchup aggregation, resume persistence/routing, canonical compatibility and migration, handicap history, completed-round pace, outcome bucketing, in-round handicap usage, and rollout calibration metrics.

## Open Questions

- None.
