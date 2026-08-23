# Pre-Round Lineup Metadata

Date: 08-18-2026

## Scope Boundary

- Changed: scheduled pre-round team lineup rows on series round cards.
- Not touched: live or completed round contributor metrics, tee-sheet editing, matchup generation, or handicap calculation.

## Design Decisions

- Show one subtle trailing label in the form `7 HCP · G7`, using the member's effective league handicap and authoritative planned tee-group index.
- Keep the compact metadata exclusive to the `.upcoming` card lifecycle so live and results rows retain their score-focused metrics.

## Deviations

- None.

## Tradeoffs

- Group labels use the existing one-based tee-group number (`G1`, `G2`, and so on) instead of adding a second matchup-side naming system.

## Validation

- The Production scheme builds successfully for a generic iOS device with Xcode 27 beta.
- Added formatter and round-card projection unit coverage; the tests compile successfully.
- Simulator test execution remains blocked by the existing target configuration embedding a watchOS-device app inside the iOS simulator app.

## Open Questions

- None.
