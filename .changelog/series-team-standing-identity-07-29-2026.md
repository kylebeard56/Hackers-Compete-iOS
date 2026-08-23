# Series Team Standing Identity

Date: 07-29-2026

## Scope Boundary

- Changed: automatic team-award identity resolution, automatic-awards engine version, team-standing display validation, and regression coverage.
- Not touched: point values, placement rules, scoring calculations, Firestore schema, or individual standings.

## Design Decisions

- Series team awards must use a current `SeriesTeam` ID. A temporary round-team ID can no longer become a standings competitor ID.
- Missing explicit mappings are recovered from deterministic round IDs, series roster membership, or a unique normalized team name.
- Ambiguous or unresolved team identity sends the round to review instead of publishing partial or duplicative awards.
- Persisted standings whose competitor is not in the current series roster are excluded from the visible team leaderboard.
- Incremented the automatic-awards engine version so completed automatic rounds are eligible for a canonical rebuild that replaces affected awards and standings.
- Restored the commissioner refresh action on the team standings tab so that rebuild can be initiated from the affected screen.

## Deviations

None.

## Tradeoffs

- A truly ambiguous legacy round requires commissioner review; this favors standings correctness over guessing.
- Existing invalid rows are hidden immediately, while their underlying awards are replaced when the automatic-awards rebuild runs.

## Open Questions

None.
