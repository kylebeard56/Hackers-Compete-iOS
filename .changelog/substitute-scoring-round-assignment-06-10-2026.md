# Substitute Scoring Round Assignment

Date: 06-10-2026

## Scope Boundary

- Changed: Series round substitute assignment, linked round sync repair, matchup scoring participation, substitute footnote text, and scoring regression coverage.
- Not touched: Completed-round reprocessing or exposing substitutes scoring as a per-round editor control.

## Design Decisions

- Substitute-role members are no longer available through standalone tee-sheet add-player flows; they can only enter a round by replacing a regular seated player.
- Regular player seat menus surface `Substitute in...` before movement controls, and group movement now nests under `Move to group` so long group lists do not dominate the menu.
- A substitute seat keeps the replaced player's round-local team via `representedTeamID`, and its menu is limited to restoring the original player.
- Linked round sync now stamps `substitutesScore` from series settings and repairs substitute metadata/team IDs from planned seats.
- Matchup presentation keeps substitute rows visible while treating them as non-counting when series settings disable substitute scoring.
- Individual matchup presentation now blocks direct score-entry fallback for disabled substitute-only sides, keeping those substitutes visible without assigning them a competitive total.
- Scoring coverage now includes matrix-style assertions for all/best/worst team scoring, per-hole versus per-round aggregation, aggregate matchup totals, hole-by-hole matchup points, gross versus net selection, Stableford highest-points selection, and substitute score inclusion/exclusion.
- Handicap coverage now pins rolling/latest/best pool policies, deterministic tie-breaks, invalid gross filtering, and games-used calculation from the eligible pool size.

## Deviations

- None.

## Tradeoffs

- Malformed substitute seats without a resolvable original player fall back to a remove action so commissioners can recover the tee sheet.
- The broad scoring coverage is concentrated in engine-level unit tests rather than UI tests so failures point at scoring semantics instead of rendering details.

## Open Questions

- None.
