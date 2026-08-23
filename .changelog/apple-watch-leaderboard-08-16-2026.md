# Apple Watch Leaderboard

Date: 08-16-2026

## Scope Boundary

- Changed: Apple Watch round projection, scoring-screen competition summary, and a read-only scrollable leaderboard/matchup destination.
- Not touched: iPhone leaderboard presentation, scoring rules, probability calculations, direct Watch networking, complications, GPS, or round selection.

## Design Decisions

- Keep score entry as the primary Watch surface and expose standings through a compact summary row plus a dedicated destination.
- Project only display-ready competition data from the iPhone so every Watch layout uses the canonical iPhone scoring and probability results.
- Omit the competition entry entirely when a round has no meaningful standings instead of showing an empty destination.
- Add competition data as an optional Watch snapshot field so previously cached snapshots remain decodable without a schema migration.

## Deviations

None.

## Tradeoffs

- The Watch remains dependent on the iPhone projection for canonical standings and probabilities, but it can display the latest cached projection while disconnected.

## Open Questions

None.
