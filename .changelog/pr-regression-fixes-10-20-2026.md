# PR Regression Fixes

Date: 10-20-2026

## Scope Boundary

- Changed: companion account restoration in PRs #16 and #17; mixed handicap entry recalculation, gross-round preflight, and frozen handicap basis validation in #16.
- Not touched: personal handicap calculation rules, production data, and unrelated local course-provider work.

## Design Decisions

- Persist the owner of the companion selection. Same-account restoration retains the selection; account changes and sign-out clear it. Legacy selections without an owner are cleared once because ownership cannot be established.
- Wait for the dashboard's initial rounds load before reconciling the saved selection.
- Reject a live/paused sync that would change a frozen allowance's scoring basis before any writes; do not reinterpret or migrate an active allowance.
- Gross-only rounds do not require handicap inputs. Net rounds retain strict validation.
- Course and tee changes use each participant's entry mode; explicit round-wide mode changes keep their existing conversion behavior.

## Deviations

None.

## Tradeoffs

- A basis-changing sync requires correcting the proposed series-round settings before retrying. This preserves live scoring without changing stored historical data.

## Open Questions

- None for these four fixes. Physical Watch and authenticated Firebase workflows were not exercised.

## Validation

- Focused suites: 196 passed, zero failed, including all ten new tests.
- Full unit suite: 1,060 passed, 23 pre-existing test failures, five skipped, plus one simulator-clone boot timeout reported as a system failure (24 failures in the result summary).
- Compared failure identifiers against the pre-change run: no additional test failure; the simulator boot timeout is the only additional failure entry.
- Added the new handicap regression suite to the PR's existing CI workflow. Existing hosted UI/keychain failures remain outside these four fixes.
