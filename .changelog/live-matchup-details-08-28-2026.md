# Live Matchup Details

Date: 08-28-2026

## Scope Boundary

- Changed: Tappable live-round matchup tiles and their matchup-specific detail/analytics experience, with a shared path for completed-round matchup outcomes.
- Not touched: Matchup scoring rules, probability simulation methodology, persistence, or unrelated live-round navigation.

## Design Decisions

- Reuse the existing live scoring, matchup probability, participant counting-probability, and round-outcome data rather than introducing a second analytics source.
- Treat a matchup tap as navigation to one cohesive detail screen instead of expanding an already dense tile in place.
- Reconstruct the probability timeline on demand at each recorded through-hole checkpoint, including a pre-round baseline, so historical movement stays deterministic without adding a persistence migration.
- Keep completed-round player scorecard actions intact and place the shared matchup breakdown alongside them.

## Deviations

None.

## Tradeoffs

- Probability history is derived from recorded scoring checkpoints rather than stored snapshots. It is calculated asynchronously with 100 deterministic scenarios per player/checkpoint and cached by matchup revision, while the current headline odds continue to use the existing 1,000-scenario forecast.
- Formats unsupported by the probability simulator fall back to an authoritative score-advantage trend instead of showing misleading odds.

## Open Questions

None.
