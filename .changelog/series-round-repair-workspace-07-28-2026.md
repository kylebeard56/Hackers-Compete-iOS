# Series Round Repair Workspace

Date: 07-28-2026

## Scope Boundary

- Changed: Completed-round commissioner repair UI and its atomic score, participant handicap, tee, scoring-unit, and reconciliation write path.
- Not touched: Live score entry, roster handicap computation, future-round seeding, and the existing GBB repair manifest.

## Design Decisions

- The main sheet is a searchable player summary; each player opens an item-driven editor sheet.
- Score, tee, and frozen Course HCP drafts accumulate across players and publish through one Save & Recompute action.
- Handicap repair is either a direct Course HCP override or an index-and-tee calculation, never both.
- Repairs change only the historical round participant and embedded scoring-unit allowances.

## Deviations

- None.

## Tradeoffs

- The manifest remains available as a guarded operational fallback, but the commissioner UI becomes the normal repair path.
- Direct Course HCP override can preserve incomplete historical tee metadata; index-based calculation requires complete rating, slope, and par.

## Open Questions

- None.
