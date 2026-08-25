# Substitute Tee Sheet Menu

Date: 06-09-2026

## Scope Boundary

- Changed: Series round tee-sheet seat menu substitution actions and eligibility.
- Not touched: Substitute scoring rules, standings, live round rendering, or round sync plumbing.

## Design Decisions

- Regular member seats now offer `Substitute in...` and replace the seat player with an unused roster substitute.
- Substitute seats keep `Playing for...`, but represented-player options are limited to active non-substitute members not currently seated in any tee group.

## Deviations

- None.

## Tradeoffs

- The change keeps the existing menu structure and planned-seat metadata instead of adding a new add-player flow inside the seat menu.

## Open Questions

- None.
