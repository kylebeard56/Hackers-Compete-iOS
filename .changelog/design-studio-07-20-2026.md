# Design Studio

Date: 07-20-2026

## Scope Boundary

- Changed: Added a Sandbox-only design studio, adaptive series-round setup prototype, local lobby/live-round prototype, semantic theme tokens, and a component gallery.
- Not touched: Existing production lobby, live round, course picker, series editor, persistence, Firebase, and telemetry behavior.

## Design Decisions

- Initial series setup uses conditional guidance; later revisions use the same applicable sections as a jump-anywhere ledger.
- Matchups only appear after a matchup competition scope is selected. Field rounds remove the section and recalculate readiness.
- Content surfaces are opaque. Material effects remain limited to navigation/transient presentation.
- The studio uses initials for players and a centralized Satoshi-compatible typography fallback.

## Deviations

- The prototype owns deterministic local mock state while retaining `SeriesRoundDraft` as the series configuration source of truth; no service-backed data is loaded.

## Tradeoffs

- The studio is compiled into the app target but all symbols and entry points are guarded by `SANDBOX`, keeping Production behavior unchanged while avoiding a second prototype target.

## Verification

- Built the Sandbox target for iPhone Simulator and the Production target for generic iOS.
- Passed all 14 focused `SeriesPhase2ConfigurationTests`, including the new conditional Matchups and readiness-transition cases.
- Completed side-by-side visual QA against the selected Series setup direction in light and dark appearances.

## Open Questions

- Licensed Satoshi font files and final mascot artwork can replace the centralized fallbacks before production promotion.
