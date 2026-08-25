# League Default Max Score

Date: 06-08-2026

## Scope Boundary

- Changed: Series round configuration storage, league settings UI, series round create/edit sheets, linked-round back propagation, and focused tests for max score defaults.
- Not touched: Live round per-round max score behavior beyond consuming the new series default.

## Design Decisions

- Store the league max score as an optional `SeriesRoundConfiguration.maxScoreOverPar` so existing leagues can omit the field.
- Resolve missing values to `Quad` when creating or editing rounds, matching the requested legacy default.
- Show all max-score options in league and series-round editors, including `2x Par` and `2x Par + 1`, because the value is a future-round default.

## Deviations

- None.

## Tradeoffs

- The model preserves nil for untouched legacy/default configs instead of eagerly writing `quad`, reducing Firestore churn while keeping behavior deterministic.

## Open Questions

- None.
