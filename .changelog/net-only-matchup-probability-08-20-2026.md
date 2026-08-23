# Competition-Basis Matchup Probability

Date: 08-20-2026

## Scope Boundary

- Changed: Matchup Monte Carlo basis selection, cross-surface probability basis validation, and probability labeling.
- Not touched: Gross score presentation, player finish-projection analytics, scoring rules, and the simulation algorithm itself.

## Design Decisions

- The matchup probability basis follows the configured competition: Net when handicaps are enabled, otherwise Gross.
- The Live Round Gross/Net picker remains a score-presentation control and no longer invalidates or launches probability work.
- Every matchup probability carries its score basis so stale or incorrectly based results can be rejected before publication.

## Deviations

None.

## Tradeoffs

- A user viewing Gross matchup scores in a handicapped round still sees the competitive Net probability, labeled explicitly as Net.

## Open Questions

None.

## Verification

- Sandbox iOS generic-device build passed with code signing disabled.
- Sandbox Watch app simulator build passed with code signing disabled.
- All 7 `LiveRoundProjectionIntegrationTests` passed, including the new Net-only and non-handicapped Gross-basis contracts.
- The normal simulator test launch remains subject to the existing project issue where the iOS simulator host embeds a device-watchOS product; the focused suite passed using the generated-product isolation workaround.
