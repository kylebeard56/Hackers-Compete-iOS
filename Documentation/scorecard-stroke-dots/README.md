# Scorecard stroke dots — October 19, 2026

## Root cause and branch comparison

PR #13 (`26092363`, merged as `731f5619`) introduced allocation-based stroke dots. The October 18 release candidate (`d03a2355`, PR #16) branches from the earlier shared ancestor `2fa84da3` and does not include those presentation changes. PR #16's current head `897278c0` differs from `d03a2355` only in release documentation.

The release candidate:

- Gates `FullScorecardView.scoreCell` dots on `strokesReceived > 0, isScored`, hiding them on unscored holes in both the live embedded table and modal scorecard.
- Lacks the individual scorecard gross-row dot renderer.
- Lacks `ScorecardStrokeDotPolicy`; its standalone hole cell has an equivalent gross-only positive-allocation condition.

The user's current checkout is `codex/wdx6zf361d-wdx6zf361e` at PR #13's head, not PR #16. It already contains all three functional changes. This work preserves that branch and its unrelated uncommitted Settings, companion, and robustness work. The source changes here document the allocation-only policy and expose the production cell/row renderers internally for regression tests. No handicap calculation, normalization, scoring rule, persistence, or completed-round snapshot code is changed.

## Release-candidate patch

`scorecard-stroke-dots-pr16.patch` is a standalone patch against `d03a2355`, also applicable to PR #16's documentation-only successor. It restores only the scorecard portions of PR #13 and adds the same regression tests. It deliberately preserves the RC's newer Course Handicap, series, personal Index, signed-allocation, Settings, and Player Insights implementations.

The patch changes:

1. `ScorecardHoleCell.swift`: restore `ScorecardStrokeDotPolicy` and use it in the existing top-trailing dot overlay.
2. `FullScorecardView.swift`: render gross-row dots from the policy independently of score entry; retain the net presentation, blank alignment marker, color, diameter, spacing, decoration, and score-edit behavior.
3. `IndividualScorecardView.swift`: restore the gross Score row's allocation dots, including unscored holes; keep the separate Net row free of dots. Keep the RC's Course Handicap detail formatting intact.
4. `ScorecardStrokeDotRegressionTests.swift`: exercise the actual production rendering as well as allocation and snapshot invariants.

The patch was prepared and tested in an isolated source export under `/private/tmp/HackersStrokeDotsRC`; no branch was switched, merged, pushed, or deployed.

## Allocation audit

- `LiveRoundViewModel.strokesReceivedOnHole` delegates to `ScoringEngine.strokesReceived` with the participant's locked allowance, tee holes, played hole range, handicap enabled flag, and allocation basis. It does not require a score.
- `scoringUnitStrokesReceived` computes the existing shared unit allowance and passes the same range/basis inputs to the engine before any score exists.
- Full/live scorecards select shared-unit allocations for shared rows and participant allocations for individual rows. They do not derive allocations from the difference between gross and net scores.
- Individual gross rows use the participant allocation for each actual played hole, as in PR #13.
- The dot policy renders `max(0, allocation)` in gross presentation and zero dots in net presentation. Negative allocations continue to affect net scores through the existing engine; they are not turned into positive received-stroke dots.

## Regression coverage

- Production full/live/insight cells before and after scores, with 0, 1, 2, and 3 received strokes.
- Standalone hole-cell rendering before/after scoring, including light/dark palettes.
- Actual individual gross/net rows; net cells render net values and no handicap dots.
- Hosted mobile full/live and individual scorecards in light and dark modes, with screenshot attachments and visible-dot assertions.
- Front nine, back nine, and eighteen holes, with nine/eighteen-hole allocation bases.
- Handicaps disabled, negative allowances, team and partnership shared scoring, and frozen completed-series participant snapshots and scores.

## Validation

Current development branch: Sandbox build-for-testing and **67 tests passed, 0 failed, 0 skipped** on Hackers Handicap Tests (iPhone 17 Pro) / iOS 26.3.1. Includes all eleven new regressions, existing Player Insights analytics, outcome/shared scoring, handicap computation, and series accrual cases. Result bundle: `/private/tmp/HackersStrokeDotsCurrentFinal.xcresult`.

Original RC rendering reproduced both regressions: **2 tests failed as expected**, with 15 dot-count assertion failures. All nine full/live failures were unscored positive allocations (1–3 dots) across modal/live/insight presentations. All six individual-row failures covered 1–3 allocations before/after scoring. Result bundle: `/private/tmp/HackersStrokeDotsRCBefore.xcresult`. The repro includes only internal renderer access and the policy definition needed to compile the tests; the full/individual rendering itself is the original RC code.

Forward patch applicability passed against pristine `d03a2355` scorecard files, identical to those at current PR #16 head `897278c0`. Reverse applicability also passed against the patched source export. Patched RC: Sandbox simulator build-for-testing and **1,084 tests passed, 0 failed, 5 existing opt-in skips**, confirmed by `xcresulttool get test-results summary` on iPhone 17 Pro / iOS 26.3.1. Result bundle: `/private/tmp/HackersStrokeDotsRCAll.xcresult`. This includes the RC's complete `HackersUnitTests` target: PR #14 Course Handicap/basis and overrides, PR #15 personal handicap history/calculation, PR #16 entry/series/scoring, and PR #17 Settings/companion behavior, plus the new dot regressions. No test was newly skipped or disabled; the existing Sandbox sanitizer settings were retained.

A blob-hash comparison against every tracked file in `d03a2355` confirms that the isolated patched export changes only the three scorecard Swift files (plus the newly added regression test). All other tracked RC files, including handicap/scoring engines and snapshot models, remain byte-identical. Xcode's automatic project-entry ordering was restored. `git diff --check` passes on the current branch.

Validation used XcodeBuildMCP `test_sim`, Sandbox scheme/configuration, simulator `C136E3C7-BE88-4383-85D3-163F366C7F60`, `-disableAutomaticPackageResolution`, `-parallel-testing-enabled NO`, and the test selections described above. The complete RC run used `-only-testing:HackersUnitTests`.

Hosted patched-RC evidence (393 × 852 points; current-branch equivalents are in its result bundle):

- [Live Gross, light](Scorecard-live-light-unscored.png)
- [Live Gross, dark](Scorecard-live-dark-unscored.png)
- [Individual Gross/Net, light](Scorecard-individual-light-unscored.png)
- [Individual Gross/Net, dark](Scorecard-individual-dark-unscored.png)

## Remaining device acceptance

On a physical iPhone, open an authenticated live round before entering scores and verify all applicable holes in the live table, full scorecard, and individual card. Enter/edit a score, toggle gross/net, and check light/dark mode on a small phone. Include front/back-nine, eighteen-hole, linked series, and an applicable shared team/partnership round. Confirm a completed historical card retains its saved allowance. Simulator rendering cannot establish authenticated listener behavior or physical-device legibility.

No merge, deployment, archive for distribution, or TestFlight upload is part of this work.
