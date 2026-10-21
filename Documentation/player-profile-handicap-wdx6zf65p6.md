# Player Profile Handicap Management — wdx6zf65p6

Ticket: <https://app.clickup.com/t/wdx6zf65p6> · Existing draft [PR #15](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/15), stacked on [PR #14](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/14) at `864af32c641f154b9be68a8fd100a73e4ce4f4cf`.

## Current result and decisions

The user approved a **WHS-inspired, unofficial Hackers personal calculator**, explicitly including nine-hole estimates and **assumed PCC = 0** when official PCC is absent. Exact GHIN parity is not required. This continues all completed work at `d5077c2`; there is no paid GHIN integration.

Complete individual 18-hole cards calculate directly from Hackers data. Initial eligible complete nines pair chronologically, and subsequent nines use a versioned expected-nine estimate based on the calculated personal Index before the round. All results are labeled **Hackers Calculated Index**, never an officially issued GHIN/USGA Index. Required conditions remain **54 actual qualifying holes and at least three valid 18-hole differential equivalents**.

## Personal calculation and eligibility

- Collect canonical regular and league rounds from both `rounds` and `rounds-v2`. Reuse the existing V2 scoring adapter and migration phase rules: staged copies do not replace V1; active V2 copies replace V1 by stable round ID, including removals/cancellation/archival. Never read a league-computed Index or its custom handicap score pool as a personal result.
- Include individually attributable complete stroke-play, match-play, Stableford and best-ball/four-ball cards. Team membership is not an exclusion. Reject Captain’s Choice/Scramble by stored root/segment IDs, normalized catalog aliases and shared-score structure; reject team-only scores, unknown/shamble formats, practice/unofficial postings, duplicates and insufficient cards. Excluded rounds remain in normal history/statistics, whose code is unchanged.
- For this unofficial app policy, completed individual cards default to inclusion unless marked otherwise. This is **not** certification of USGA season, peer-review, jurisdiction or Rules-of-Golf compliance. Owners and permitted persistent offline-player managers can mark a posting Practice, Unofficial or Needs review from personal history. Those metadata edits never change gross scores or frozen scoring allowances.
- Use the stored first-scored date, or the earliest required/persisted score-entry creation time on older cards, never the correction timestamp. Store that date provenance; these are Hackers recorded scoring dates, not independently certified dates of play.
- Require exact selected-tee rating, slope and par. Reuse PR #14’s provenance-aware metadata resolver; estimated nine-hole metadata cannot qualify. Keep recorded individual gross strokes visible even when missing tee data prevents calculation.
- Preserve manual decimal 18-hole Index, source and update date. Legacy integer allowances are never interpreted as Indexes. Use a frozen personal input where present, otherwise the valid replayed personal history, otherwise a manual Index whose recorded update predates play. Store the provenance used for hole limits. Do not use a league allowance as the personal input.
- Compute adjusted gross only for the personal projection: initial par+5, otherwise net double bogey with unrestricted personal Course Handicap (including plus strokes given back). Nine-hole Course Handicap uses the rounded half Index and actual rated nine. Gross scorecards, scoring caps and participant snapshots are never rewritten.
- Record `pcc.value`, `pcc.verification` (`assumed`/`verified`) and `pcc.source` on each calculated/pending score. Missing official PCC uses `0 / assumed / Hackers assumption: official PCC unavailable`. A valid externally supplied `personal_handicap_pcc` on the canonical round takes precedence. Invalid values/provenance are rejected; a verified zero is distinct from assumed zero. No official PCC is computed from Hackers players’ results.
- Standard 18-hole differential: `113 / slope × (adjusted gross − rating − PCC)`. Apply the published fewer-than-20 table; lowest eight of latest 20; maximum 54.0; published negative tie rounding; exceptional reductions against the unrounded differential; cumulative reductions over the then-latest 20 and dilution; Low Index and soft/hard caps. No league 0.96 factor.
- Enforce 54 actual qualifying holes and three valid differential equivalents. Eligible nines count nine actual holes, not 18. Select from the latest 20 **differential equivalents**, counting a pair once and mapping counting/pool membership back to both source cards. Unpaired initial nines advance progress without occupying an invented differential slot. Other unresolved eligible conversions (such as partial cards) retain their existing pending behavior rather than being silently omitted. A last valid Index can remain effective while such a later card is pending; corrections removing every valid historical prefix restore manual/unavailable state.

## Approved nine-hole policy and approximation

### Establishment: `hackers-paired-nine-v1`

1. Traverse eligible individual rounds in play-date order, with stable round ID as the tie-breaker. Include regular and every league's individual cards in one personal record. Skip excluded/ineligible cards before pairing.
2. Pair consecutive **complete rated nines** while no calculated personal Index exists. Eighteen-hole cards may occur between those nines and retain their own differential. A nine belongs to at most one pair.
3. Sum the two **unrounded** played-nine differentials, including each card's own half-PCC adjustment; round the combined result to a tenth once. Retain both card IDs, one stable differential ID, method/version, original course/tee data and each card's gross/adjusted gross. The pair enters the chronological pool on the later nine's date.
4. Activate only after 54 actual holes and three valid equivalents. Six nines produce three pairs; three eighteens produce three differentials; valid mixtures work. The manual Index is never a qualifying score or the source of an expected-nine estimate.
5. An unpaired initial nine remains visible with its actual holes and played differential. If full eighteens establish an Index before another initial nine arrives, that leftover card stays unpaired; later nines use the established method and never reuse it. Chronological corrections can change those outcomes on replay.
6. A synthetic initial pair does not trigger an exceptional-score reduction: it has no single pre-round established personal Index. Existing reductions from qualifying actual/expected-score entries, selection, rounding, maximum Index, Low Index and caps remain in force.

### After establishment: `hackers-expected-nine-linear-bounded-v2`

For each new complete nine, use the last valid **calculated personal Index from the chronological prefix before that round**, not the current profile, manual starting value, league Index, next result, or an unrelated frozen allowance:

```text
modelIndex = max(-6.0, preRoundCalculatedPersonalIndex)   # finite Index, maximum 54.0
expectedNine = 0.52 × modelIndex + 1.2
playedNine = 113 / nineSlope × (nineAdjustedGross − nineRating − PCC / 2)
estimated18 = roundToTenth(playedNine + expectedNine)
```

Both components remain unrounded until the final sum. Store the unrounded expected component, actual pre-round calculated Index, bounded model Index, played component, final differential and method/version. Negative numbers represent plus handicaps. The estimate is deterministic, course-independent (the played component already adjusts course difficulty), and isolated in `PersonalHandicapNineHoleEstimation`. Its estimated 18-hole result joins the normal pool immediately and uses the same pre-round personal Index for existing exceptional-score checks. Actual holes remain nine.

**Evidence and limitations.** The USGA's 2024 treatment infographic gives Index 14.0, played-nine differential 7.2 and combined 15.7; this approximation supplies 8.48 and rounds the sum to 15.7. Its Understanding Expected Score infographic gives Index 15.0 with expected-nine 9.0 on two courses; applying the actual rating/slope calculations reproduces combined 14.6 and 20.5. Those two nearby Index examples alone would be insufficient to validate a general model. We therefore also checked 13 independent representative points across Swiss Golf's published 2025 expected-differential table, from numeric Index -6.0 through 54.0: the approximation's rounded expected component matches each tested value. Regression tests retain these primary-source comparisons. This is empirical support for a simple approximation, **not** proof of the USGA's formula, underlying population distribution or GHIN equivalence.

**Candidate evaluation requested in the follow-up.** We also evaluated `0.5 × Index + 1.5`. It reproduces the two USGA Index-14/15 examples at their displayed precision, so those examples do not distinguish the candidates. Against the same 13 representative Swiss Golf table points, the candidate matches 2/13, has maximum rounded-component deviation 0.8 strokes (at Index 54), and mean absolute deviation about 0.277. The retained `0.52 × Index + 1.2` model matches 13/13 at the table's one-decimal precision. These are cross-checks against published rounded values, not evidence of exact official internal calculations.

| Numeric Index | Published expected nine | Retained model, rounded | Candidate, rounded |
| --- | --- | --- | --- |
| -6.0 (+6) | -1.9 | -1.9 | -1.5 |
| 0.0 | 1.2 | 1.2 | 1.5 |
| 14.0 | 8.5 | 8.5 | 8.5 |
| 15.0 | 9.0 | 9.0 | 9.0 |
| 38.0 | 21.0 | 21.0 | 20.5 |
| 54.0 | 29.3 | 29.3 | 28.5 |

**Supported range and bounds.** The published table spans numeric Index -6.0 through 54.0. The model never extrapolates below that range: a better-than-+6 player uses model Index -6.0, yielding an unrounded expected-nine component of -1.92. Their actual historical Index remains stored separately and still controls existing exceptional-score checks; neither the Index nor completed allowances are clamped. Reject non-finite inputs and inputs above 54.0 (the calculated personal Index already has that maximum). The expected component is thus bounded to [-1.92, 29.28]. Score details expose any bounded model input. Version v2 replaces v1's unvalidated lower-tail extrapolation; whole-record method version is `hackers-whs-inspired-nine-hole-v4`.

Known differences: initial chronological pairing differs from current WHS establishment processing; a linear model may diverge at untabulated values or after official model changes; plus handicaps better than +6 use the +6 boundary for their expected component, which can conservatively overstate the expected differential relative to an unknown official value; assumed zero PCC may differ from official course/day conditions; score acceptability relies on Hackers data and user posting metadata. Neither the model nor coefficients are fitted from Hackers users' scores. No official PCC is generated.

### Partial cards

Existing partial-round validation/progress is preserved. A valid reason and a complete exactly rated nine are required. Before an established personal input, only that rated nine contributes to progress. With an established personal input, retain supported actual played holes and adjusted gross. Partial-round normalization beyond complete-nine cards remains pending: this approval covers complete-nine estimates, not invented missing-hole scores or scaled partial Course Ratings. No source scorecard is filled or modified.

## Persistence, recalculation and round creation

- Deterministically replay canonical source revisions, with SHA-256 input fingerprints and stable player/round identities. Rebuild on profile load/Refresh and immediately before ordinary-round creation or adding ordinary participants. V1 completion also performs a best-effort refresh for manageable profiles. V2 results/corrections are reflected by the same source refresh before use. There is no new server deployment or background job.
- Persist individual provenance rows under `players/{playerID}/personal-handicap-scores/{roundID}` and actual calculated trend points under `personal-handicap-history/{roundID}`. Remove obsolete derived rows/points after exclusion, correction, deletion or routing changes. Preserve dates of semantically unchanged historical calculations.
- Publish only profile calculation/effective projections; manual input and unrelated player fields are preserved. Every transaction page and final summary checks a refresh-generation token claimed before reading inputs. A newer refresh or concurrent manual edit invalidates older publication. Large histories are paged under Firestore’s write limit; readers always derive from canonical sources rather than trusting a partially published cache.
- Preserve collecting/qualified wire statuses for the earlier Sandbox PR #15 build, with an additive `calculation_pending` flag interpreted by the current client. New fields are optional for legacy player/round/V2 documents.
- Regular creation attempts to refresh the personal result before capturing it and uses PR #14’s Course Handicap/snapshot behavior. A refresh failure retains the saved personal profile so gross setup can continue; missing inputs remain unresolved and the existing net activation checks still apply. Round-only overrides, tee recalculation, historical participant snapshots and independent league calculations remain intact. Read-only registered profiles calculate locally without modifying another owner’s cache; persistent offline identities retain existing management permissions.
- Profile reuses the league card/chart design: effective/manual/calculated (or last valid) values, chronological calculated points including approved estimates, qualifying rounds/holes, differential pool/counting totals, and Counts / Pool / Pending / Unofficial rows. Exact versus estimated differential labels appear in history; pair membership shares one counting status. All viewers can open score details for course/tees, gross/adjusted gross, rating/slope, PCC provenance and method/version. The main profile keeps a short unofficial label and places methodology in an expandable explanation. Posting edits retain existing owner/offline permissions.

## Primary rule references reviewed

- [USGA treatment of nine-hole scores, worked Index 14 example](https://www.usga.org/content/dam/usga/pdf/2024-revision/Detailed-Infographic-2024-9-hole-scores.pdf)
- [USGA Understanding Expected Score, Index 15/two-course examples](https://www.usga.org/content/dam/usga/images/handicapping/infographics/Understanding%20Expected%20Score%20Infographic.pdf)
- [Swiss Golf 2025 expected-nine differential table, -6.0 through 54.0](https://swissgolf.ch/media/9-hole_expected_score_differential_2025_2.pdf) — broad-range cross-check only; not an authorized GHIN feed.

- [USGA 2.1a — authorized formats](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/2%201a%20Played%20in%20an%20Authorized%20Format%20of%20Play.htm)
- [USGA 3.1b — net double bogey](https://www.usga.org/handicapping/roh/Content/rules/3%201b%20After%20a%20Handicap%20Index%20Has%20Been%20Established.htm), [6.1b — nine-hole Course Handicap](https://www.usga.org/handicapping/roh/Content/rules/6%201b%209%20holes.htm)
- [3.2a — valid reasons for holes not played](https://www.usga.org/handicapping/roh/Content/rules/3%202a%20Reason%20for%20Not%20Playing%20One%20or%20More%20Holes.htm)
- [Nine-hole expected-score explanation](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---expected-score-explained.html), [initial nines/54 holes](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---new-player-treatment-of-9-hole-scores.html), [initial 10–17 holes](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---10-17-holes-whike-establishing-handicap.html)
- [5.2a — calculation table](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%202a%20For%20Fewer%20Than%2020%20Scores.htm), [5.1c — minus rounding](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%201c%20Calculation%20of%20a%20Score%20DifferentialRoundingMinus.htm)
- [5.6 — PCC](https://www.usga.org/handicapping/roh/Content/rules/5%206%20Playing%20Conditions%20Calculation.htm), [5.7 — Low Index](https://www.usga.org/handicapping/roh/Content/rules/5%207%20Low%20Handicap%20Index.htm), [5.8 — caps](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%208%20Limit%20on%20Upward%20Movement%20of%20a%20Handicap.htm), [5.9 — exceptional scores](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%209%20Submission%20of%20an%20Exceptional%20Score.htm)

## Validation

The final relevant regression run passed **430 tests, zero failures/skips** on iPhone 17 Pro / iOS 26.3.1, confirmed by `xcresulttool get test-results summary`. It includes **68 personal calculation/eligibility tests (22 beyond `d5077c2`, including four follow-up cases)** and 27 personal profile tests.

The result bundle is `/private/tmp/HackersPersonalHandicapNineBounds-final.xcresult`. Validation used project `Hackers.xcodeproj`, scheme/configuration `Sandbox`, signing disabled, Address Sanitizer/code coverage disabled, serial simulator tests, and these `-only-testing:HackersUnitTests/<suite>` selections:

```text
PersonalHandicapCalculationTests  PersonalHandicapProfileTests
CourseHandicapCalculationRegressionTests  ScoringEngineTests
SeriesRoundCreationMappingTests  RoundParticipantHandicapOverrideTests
HandicapComputationTests  SeriesRoundSyncServiceTests
SeriesHandicapHistoryTests  SeriesRoundHandicapAccrualTests
SeriesRoundCodableTests  RoundActivationMatchupValidationTests
SeriesRoundV2Tests  ScoreCarouselSelectionTests
RoundSessionLifecycleTests  RoundSessionReloadTests
LiveRoundResumeRegressionTests  AppSessionResumeTests
FirebaseIDValidationTests  RoundSessionReadinessTests
```

The separate **Sandbox simulator build passed** with `CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES`. Log: `/private/tmp/HackersPersonalHandicapNineBounds-final-build.log`. `git diff --check` passed. No league algorithm, completed scorecard, historical stroke allowance, PR #14, merge or deployment was changed by this work.

Relevant suites cover personal calculation/profile, Course Handicap, scoring, commissioner overrides, league computation/history/accrual, series creation/sync, Codable, activation, V2 and round/session lifecycle behavior. New cases cover six nines, three eighteens, mixtures, cross-league pairing, unpaired initial cards, single-use pairing, pre-round expected estimates across plus/low/high Indexes, USGA/table comparisons, late/corrected/excluded scores, source-card versus differential pool counts, last-20 selection, manual retention, metadata persistence and frozen source snapshots. Follow-up cases cover bounded extreme-plus estimates with separate historical/model provenance, deleted postings with idempotent replay, and older imports that change pairing and subsequent expected inputs.

Live authenticated Firebase transactions/save-reload, concurrent multi-device publication, manual UI and physical-device acceptance were not exercised. Firebase admin inspection failed because existing credentials require reauthentication; no login, rules/database changes or deployment was attempted. Existing app-host Firebase permission/keychain and unpaired-watch messages can occur during unit tests. Source uses the existing `(default)` Firestore instance and SDK rather than provisioning or switching databases.

## Internal release reliability follow-up

Player addition now treats personal-history refresh as best effort. `RoundSession.addPlayers` uses the shared `refreshingPersonalHandicapsForSetup` path, which catches each player's refresh failure and continues with that player's saved personal profile. A successful refresh replaces only the personal profile, leaving identity and legacy strokes alone. Nil or mismatched results retain the saved profile. No legacy integer allowance is promoted to an Index; absent personal data stays unresolved through existing prefill. Existing calculated/manual preference, manual source/date, league calculations, and frozen participants are unchanged.

Eight new `PlayerSetupHandicapRefreshTests` exercise disconnected and lost networks, timeout and permission failures, saved calculated/manual fallback, missing legacy-only profiles, continued processing of other players, successful refresh, missing results, league exclusion, and completed-round preservation. **103 tests passed, 0 failed, 0 skipped** (8 new refresh regressions, 68 calculation tests, 27 profile tests) on iPhone 17 Pro / iOS 26.3.1. Result bundle: `/private/tmp/hackers-release-pr15-refresh.xcresult`. The simulator test build and `git diff --check` passed. These tests inject refresh outcomes; they do not claim authenticated Firebase concurrency or physical-device validation.

The same failure dependency also existed for the primary player in `CourseSelectionViewModel.createRoundLobby`. Lobby creation now keeps the saved personal profile when history is unavailable, with the existing unresolved-net activation gate retained. The refresh updates only matching personal profile data. Two additional regressions exercise this exact lobby refresh helper. Final focused validation: **115 passed, 0 failed, 0 skipped** (10 refresh/lobby regressions, 68 personal calculation, 27 profile, 10 course-selection cases), `/private/tmp/hackers-release-pr15-lobby-refresh.xcresult`. Combined-app release validation is tracked separately on PR #16; this focused result is not a release approval.

## Review-comment corrections

Addresses the [combined audit on PR #15](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/15#issuecomment-6206791402), including the three inherited setup findings. All changes are on PR #15's existing branch; PR #14's branch remains unchanged.

- **Historical manual input:** saving the same value/source is a no-op, including the original manual date, player timestamp and refresh token. Real value/source edits and removals append dated `personal_handicap.manual_history` revisions in the existing player transaction. The first edit seeds the known legacy manual entry. Replay selects the manual input effective when the round was played, with frozen round input and established calculated history retaining precedence. Explicit removal stops future manual fallback without deleting earlier inputs. Equal-time edits use the last revision. Optional fields retain old-document compatibility. Values lost before this history existed cannot be recovered and are never guessed.
- **Plus handicaps:** ordinary Index-based setup now opts into signed Course Handicap allowances. Plus players give strokes back starting at the highest published stroke indexes of the actual holes played. Relative match play subtracts the signed lowest allowance. Existing league callers keep their nonnegative allowance policy; league algorithms, caps, commissioner overrides and persisted completed allowances are unchanged. References: [USGA stroke-index allocation, Appendix E](https://www.usga.org/handicapping/roh/Content/rules/Appendix%20E%20Stroke%20Index%20Allocation.htm) and [USGA handicap allowance examples](https://digital-pd.usga.org/content/dam/usga/pdf/Handicap-Allowances-detailed.pdf).
- **Refresh failures:** retained and revalidated the existing best-effort creation/player-addition fixes in `df7805a3` and `0fc3aa13`. Saved personal profiles remain available during failure; missing inputs do not become zero or legacy-derived Indexes. Net activation still requires resolved handicap inputs.
- **Legacy nine-hole basis:** changing the source Index basis in a lobby now also reconciles allocation basis to the actual played segment. A nine-hole Course Handicap is allocated once rather than being halved again because of a stale explicit eighteen-hole basis.
- **Started-round editing:** course/tee and Index-format/basis controls use the same lobby-only policy as their setters. The UI explains the lock; Manage Player closes setup sheets when status changes. Dedicated league commissioner round-only overrides remain available under their existing permissions. Unrelated name/group editing preserves frozen handicap fields.
- **Missing Index:** Manage Player accepts an empty Index while saving unrelated gross-round fields, preserving an unresolved optional Index rather than inventing zero. Manual-stroke entry still requires a finite number, and existing net-readiness checks reject unresolved input.

The two audit reproducers were first run against the unchanged `0fc3aa13` production code and failed as reported (manual historical adjusted gross/Index and plus round allowance/allocation). After the fixes, **212 focused tests passed** in `/private/tmp/HackersPersonalHandicapAudit-fixed.xcresult`. New coverage includes registered/offline manual edit/removal persistence, historical replay after real edits, plus full/nine-hole prefill, actual net stroke-play and relative match-play results, allocation-basis migration, unresolved gross edits, and live/paused/completed setter guards. No source scorecard or completed-round snapshot is rewritten.

Final expanded regression validation: **552 passed, 0 failed, 0 skipped**, confirmed by `xcresulttool get test-results summary` for `/private/tmp/HackersPersonalHandicapAudit-final.xcresult`, on iPhone 17 Pro / iOS 26.3.1. Uses the same Sandbox simulator test flags listed above, all 20 original suite selections, plus `PlayerSetupHandicapRefreshTests`, `CourseSelectionViewModelTests`, `CompetitionScopeTests`, `ScoringPipelineStageTests`, `SegmentResolverTests`, and `GameTemplateValidationTests`. Adds 17 regression methods for this audit. Live authenticated Firestore transactions, multi-device concurrency, manual UI acceptance and physical-device checks remain untested; expired Firebase inspection credentials were not changed.

The separate **Sandbox simulator build passed** with `CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES`; log: `/private/tmp/HackersPersonalHandicapAudit-final-build.log`. `git diff --check` passed. PR #15 remains draft; no merge or deployment was performed.

### PR #14 backport compatibility

The user subsequently authorized fixing PR #14 itself. Its three setup corrections were backported in `da7646bb`, without the personal-profile or plus-handicap changes. PR #15 now uses the identical `HandicapCalculator.isValidDraft` helper from the base implementation instead of keeping draft validation in its personal-profile model. This relocation preserves behavior and avoids conflicting implementations when the stacked branches are combined. Personal calculations and all other PR #15 fixes are unchanged.

After relocation, **212 focused tests passed, 0 failed, 0 skipped** on iPhone 17 Pro / iOS 26.3.1, confirmed by `xcresulttool get test-results summary`: personal calculation/profile, Course Handicap, scoring, and setup-refresh suites. Result bundle: `/private/tmp/HackersPR15SharedValidation.xcresult`. The simulator test build and `git diff --check` passed. PR #14 separately passed 433 regression tests and a standalone Sandbox simulator build. Existing live Firebase/manual UI/device validation limits remain. No PR was merged or deployed.
