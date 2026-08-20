# Live Round Realtime UX

Date: 08-11-2026

## Scope Boundary

- Changed: Matchup probability invalidation/loading behavior, live hole score input responsiveness/default selection, and gross scoring mix visualization semantics.
- Not touched: Probability simulation math, persisted score schema, series leaderboard behavior, or unrelated in-progress changes.

## Design Decisions

- Matchup probability refreshes will be scoped to matchups whose participating players' score inputs changed.
- The scoring mix visualization will make vertical position communicate score quality, with better outcomes above worse outcomes.

## Deviations

- None.

## Tradeoffs

- Pending implementation investigation.

## Open Questions

- None.
