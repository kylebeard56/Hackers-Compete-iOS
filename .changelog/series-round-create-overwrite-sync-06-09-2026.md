# Series Round Create Overwrite Sync

Date: 06-09-2026

## Scope Boundary

- Changed: Linked round creation now resolves the league default max-score setting when building the root round configuration.
- Changed: Series round tee-sheet refresh now preserves existing planned starting holes unless the commissioner explicitly regenerates the tee sheet.
- Not touched: Completed-round scoring, Firestore schema shape, or live-round score migration.

## Design Decisions

- Treat league max-score defaults as authoritative at the creation boundary, matching the sync boundary behavior already added for existing linked rounds.
- Treat saved planned tee group starting holes as source data during ordinary sheet refresh/reopen flows; only regeneration should recalculate starts.

## Deviations

- None.

## Tradeoffs

- The fix keeps the existing creation and sync services but tightens their shared mapping behavior instead of doing a larger destructive rebuild refactor in this pass.

## Open Questions

- A larger refactor could still collapse create and overwrite into a single explicit “series source -> round snapshot” planner, but this patch addresses the observed max-score and tee-start regressions directly.
