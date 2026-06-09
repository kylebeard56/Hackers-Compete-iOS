# Bulk Handicap Score Delete

Date: 06-09-2026

## Scope Boundary

- Changed: Added bulk-select deletion controls to the member handicap score history sheet.
- Not touched: Duplicate detection/repair scripts, standings recalculation, and the legacy add-baseline score sheet.

## Design Decisions

- Bulk edit state is local to the score history sheet and reuses the existing handicap score delete API.
- The sheet keeps single-row menus outside edit mode, then replaces them with selectable check circles while editing.

## Deviations

- The delete confirmation uses a polished confirmation phrase rather than the exact rough copy from the request.

## Tradeoffs

- Bulk delete deletes selected rows sequentially through the existing view model method, which keeps recalculation behavior consistent with current single deletes.

## Open Questions

- None.
