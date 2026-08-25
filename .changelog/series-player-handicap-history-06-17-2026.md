# Series Player Handicap History

Date: 06-17-2026

## Scope Boundary

- Changed: Series member handicap breakdown summary and score rows.
- Not touched: Handicap computation rules, score ingestion storage schema, or round creation behavior.

## Design Decisions

- Show current effective index beside a capped course-handicap chip for the member's default tee on the league default course.
- Show historical round course handicap and handicap index from the linked round participant when available, so old rows reflect what was actually used.
- Keep baseline score rows focused on baseline score history and avoid showing round-only usage chips.

## Deviations

- None.

## Tradeoffs

- Older round rows without a loadable linked round snapshot may omit historical usage chips rather than guessing from the current index.

## Open Questions

- None.
