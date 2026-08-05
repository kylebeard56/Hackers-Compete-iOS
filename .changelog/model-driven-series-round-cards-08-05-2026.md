# Model-Driven Series Round Cards

Date: 08-05-2026

## Scope Boundary

- Changed: Shared V1/V2 round-card presentation contracts, model adapters, Series round-list card layout, version-routed Series round loading, and focused tests.
- Not touched: Live-round scoring behavior, round gameplay navigation internals, or unrelated analytics work already present in the worktree.

## Design Decisions

- The card renders a version-neutral value model and never computes scoring rules in SwiftUI.
- V1 linked rounds prefer the playable Round configuration; unlinked planned rounds use the SeriesRound configuration.
- V2 always uses RoundV2 configuration plus its frozen Series context; current Series defaults do not override an existing round.
- Per-hole Best/Worst N formats describe variable contributors rather than presenting a fixed counting pair.

## Deviations

- V2 gameplay screens are not reimplemented as part of the history-card redesign; version-routed V2 round loading and presentation are added while navigation remains guarded by the currently available V2 destinations.

## Tradeoffs

- Completed-round presentation can consume persisted canonical results when available and otherwise degrades to model/configuration context without adding realtime listeners.

## Implementation

- Added a shared card state, V1/V2 configuration adapters, and a common scoring-presentation builder.
- V1 linked rounds and V2 snapshots both run through the existing scoring engine for matchup and field results.
- Redesigned the Series round tile to show format-native side scores, participation, handicap, contributor context, and truthful Best/Worst N scope labels.
- Added an optional versioned `card_projection` to canonical round results and regenerate it through canonical publication.
- Routed dashboard and Series detail reads through `SeriesRecord`, with active V2 records loading canonical `rounds-v2` by `series_context.series_id`.
- Added a V2 read-only round detail destination keyed by canonical round ID.

## Verification

- Generic iOS production build succeeded.
- `SeriesRoundCardPresentationTests`: 8 tests passed, covering V1/V2 semantic parity, V1 precedence, frozen V2 defaults and context rules, Best/Worst/All variants, presentation scope, legacy decoding, and projection round-trip.
- `SeriesRoundV2Tests`: 9 tests passed, including staged, active, missing-target, and rolled-back route selection.
- `SeriesPhase8RuntimeArchitectureTests`: 8 tests passed, including the completed-history realtime listener-budget guard.
- Completed history continues to use one-time canonical reads; the realtime listener topology is unchanged.

## Open Questions

- None.
