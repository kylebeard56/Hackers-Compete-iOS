# Companion Selection Restoration

Date: 10-20-2026

## Scope Boundary

- Changed: retain the Watch/Live Activity round selection when restoring the same account, with regression tests.
- Not touched: handicap features in the separate PR stack and unrelated local work.

## Design Decisions

- Persist the selection's account owner. Clear the selection on account switches and sign-out.
- Clear legacy selections with unknown owners once; adopting them could carry a round across accounts.
- Wait for the dashboard's initial round load and player identity before reconciling eligible rounds.
- Apply the same companion code change to both PRs #16 and #17.

## Deviations

None.

## Tradeoffs

- The unknown-owner migration may require selecting a round again once after upgrading.

## Open Questions

- Physical Watch and authenticated multi-account behavior still require device validation.

## Validation

- Independently built PR #17 and ran UserCompanionPreferencesTests and LiveRoundCompanionContractTests: 34 passed, zero failed or skipped.
- Used iPhone 17 Pro Simulator, iOS 26.4.1, with parallel simulator testing disabled.
- The same companion fix also passed the 196-test focused suite on PR #16.
