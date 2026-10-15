# Player Profile Handicap Management — wdx6zf65p6

Ticket: <https://app.clickup.com/t/wdx6zf65p6> · Existing draft PR: <https://github.com/kylebeard56/Hackers-Compete-iOS/pull/15>

## Current status

The user has selected current USGA/WHS methodology, with 54 qualifying holes and current expected-score treatment. **Policy approval is no longer the blocker. Exact end-to-end calculation remains blocked by missing verified posting/USGA calculation inputs.** The app does not silently replace those inputs with estimates. PR #15 remains draft and must not be described as complete or ready to issue a calculated Index.

Work continues on the original `codex/wdx6zf65p6-player-profile-handicap` branch, based on PR #14 at `864af32c641f154b9be68a8fd100a73e4ce4f4cf`. Neither dependency PR nor unrelated working changes are modified. No deployment is part of this update.

## Preserved profile work

- Manual personal Index: decimal, 18-hole basis, source/date, independent registered and persistent offline identities. Missing is nil; legacy integer allowances remain strokes. Transactional manual edits preserve other profile fields and the manual record survives calculated-source transition.
- Separate effective/manual/calculated displays, reusable personal trend/history UI, read-only league handicaps/navigation, and ordinary-round prefill using PR #14's canonical Course Handicap resolver. Frozen participants, scoring, league overrides/accrual and the league calculation formula are untouched.

## Added in this continuation

- Canonical individual-round review across ordinary and league source rounds. Root template IDs and segment IDs are inspected before any registry fallback. Captain’s Choice/Scramble aliases are normalized (including apostrophe/space/hyphen variants and stored scramble IDs). Shared score source, shared ownership and legacy combined-handicap modes are also excluded. Shamble and unknown formats are not silently treated as stroke play.
- Individually attributable stroke-play, match-play, Stableford and best-ball/four-ball cards can pass the structural review regardless of team or league membership. The evaluator requires a unique identity, valid individual gross entries, exact rated tee/segment metadata and a complete card. PR #14's metadata provenance prevents accepting estimated nine-hole ratings.
- Practice and unofficial posting purposes are excluded. Completed status alone does not certify acceptability under Rules 2.1–2.2. Existing records lack verification of practice status, season, company/Rules of Golf and valid reasons for unplayed holes, so they remain explicitly pending.
- Captain’s Choice remains in the profile's reviewed score history with an exclusion reason; it never enters qualifying totals, pool or trend. Review never writes, removes or changes source rounds or statistics. Existing general round-history/scoring code is unchanged.
- Published calculation components: 54 actual holes, standard 18-hole scale, differential formula with explicit PCC, nine-hole half-PCC and supplied expected differential, correct negative tie rounding, initial par+5/NDB maximum helper, the complete fewer-than-20 table, lowest 8 of latest 20, 54.0 maximum, cumulative exceptional reductions over the last 20 differentials and their dilution, Low Index/soft/hard-cap calculation.
- A deterministic replay boundary accepts **verified, unrounded 18-hole differentials** tied to a player/round/review revision and external posting identity. It rebuilds counts, current selection, score statuses and chronological personal trend after corrections/exclusions. Duplicate round revisions and duplicate external postings cannot inflate qualification. Missing or stale inputs block the current calculation instead of selecting an incomplete pool.
- Automatic source transition is tested using real replay outputs, retaining the manual value. No legacy integer or league Index is used as a personal Index. Replay never modifies participant snapshots.
- Profile history now reviews canonical source scorecards when loaded, replacing the previous empty producer-less subcollection reads. It propagates read failures, labels excluded rows “Unofficial” and unresolved rows “Pending,” and shows a 54-hole progress/blocked state. The app supplies **no fabricated verified differential or eligibility attestation**, so live calculated values remain unavailable pending the integration below.

## Verified USGA rules and implementation boundaries

| Rule | Requirement and handling |
| --- | --- |
| [2.1a — authorized formats](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/2%201a%20Played%20in%20an%20Authorized%20Format%20of%20Play.htm) | Individual stroke play, match play and four-ball may qualify. Team membership alone is not exclusion. Full acceptability still needs verification. |
| [3.1 — initial maximum](https://www.usga.org/content/dam/usga/pdf/2024-revision/2024-Rules-of-Handicapping-USGA.pdf), [3.1b — NDB](https://www.usga.org/handicapping/roh/Content/rules/3%201b%20After%20a%20Handicap%20Index%20Has%20Been%20Established.htm) | Par+5 before an Index; later full unrestricted Course Handicap, including plus-player strokes given back. The helper is tested; the live adapter does not claim to have a certified adjusted gross score. |
| [5.1 / 5.6 — differentials/PCC](https://www.usga.org/handicapping/roh/Content/rules/5%206%20Playing%20Conditions%20Calculation.htm) | PCC is an official course/day statistical input. Missing PCC is an error. Having fewer than eight scores **inside Hackers** does not prove a course/day PCC of zero. |
| [5.1b — nine-hole score](https://www.usga.org/handicapping/roh/Content/rules/5%201b%20Calculation%20of%20a%20Score%20Differential9Hole.htm), [expected-score FAQ](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs/faqs---expected-score-explained.html) | A nine-hole differential is combined with the required expected differential; it is not doubled or paired. The helper requires that supplied value and keeps the played nine unrounded until combination. No numeric expected-score function is invented. |
| [Initial nine-hole scores](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/Committee%20Content/USGA/LG_R5a.htm) | Initial nine-hole expected processing occurs after 54 holes have been posted. Tests with supplied normalized differentials exercise six nines and mixed records; the app does not bootstrap expected values itself. |
| [Unplayed-hole FAQ](https://www.usga.org/content/usga/home-page/handicapping/world-handicap-system/world-handicap-system-usga-golf-faqs.html) | Established players' qualifying 10–17-hole rounds require verified reasons, hole data and official expected-score processing. Before an initial Index, only rated nine/18 posting options apply. Partial/picked-up records remain pending rather than receiving invented net-par/most-likely scores. |
| [5.2a — selection table](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%202a%20For%20Fewer%20Than%2020%20Scores.htm), [5.1c — minus rounding](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%201c%20Calculation%20of%20a%20Score%20DifferentialRoundingMinus.htm) | Published selection/adjustment table; best 8/20; nearest tenth, with exact negative ties toward zero. No league multiplier. |
| [5.7 — Low Index](https://www.usga.org/handicapping/roh/Content/rules/5%207%20Low%20Handicap%20Index.htm), [5.8 — caps](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%208%20Limit%20on%20Upward%20Movement%20of%20a%20Handicap.htm) | Low Index begins at 20 acceptable scores. Existing Low is used before updating its window, including after long gaps. Soft limit halves movement above +3; hard limit +5. Final production processing must use verified play dates/revision timing and full history. |
| [5.9 — exceptional scores](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%209%20Submission%20of%20an%20Exceptional%20Score.htm) | Compare unrounded differential to the Index in effect when played. Reductions accumulate over the then-latest 20; subsequent scores do not inherit old adjustments. |

All generated outputs are **unofficial Hackers calculations**, never an issued GHIN Index.

## Remaining blocker and work required to finish

The repository has no GHIN/USGA-authorized provider or verified import pipeline for:

1. Official course/day PCC values, including later adjustments.
2. Official expected-score normalization for nine-hole and valid partially played rounds, including initial qualification from nines.
3. Confirmed posting acceptability, actual play date, the personal Index in effect, and Rule 3 adjusted gross/most-likely scores where necessary. `Round.status == complete`, league allowances, or the current profile Index do not establish these historical facts.

The published pages reviewed explain expected-score treatment but do not supply the numeric expected-score function/data needed by this repository. An integration or supplied authoritative inputs is required; the code does not infer zero PCC or reverse-engineer an expected score.

After that provider is available, bind its results to canonical score revisions; handle partial-round normalization and initial-nine bootstrap; verify home-association daily revision/date conventions and Low Index edge cases; publish summaries/history atomically; wire authoritative completion/correction/exclusion reconciliation and fresh regular-round prefill. **Current review runs when the profile loads; no background/event-driven calculation publication or persisted calculated Index is enabled.** The automatic transition and chart replay are covered with verified-input test fixtures, not live provider data. This is a deliberate failure to calculate when required facts are unavailable, not a claim of finished end-to-end behavior.

The ClickUp MCP re-read was rate limited during this continuation. The full ticket had been reviewed previously; the user's latest requirements govern this update.

## Validation

**347 passed, 0 failed, 0 skipped**, confirmed with `xcresulttool get test-results summary`, on iPhone 17 Pro / iOS 26.3.1. This includes **25 new calculation/eligibility tests** plus the previous profile and dependency regressions. **Sandbox simulator build passed** (`xcodebuild ... build CODE_SIGNING_ALLOWED=NO`).

Suites: `PersonalHandicapCalculationTests`, `PersonalHandicapProfileTests`, `CourseHandicapCalculationRegressionTests`, `ScoringEngineTests`, `SeriesRoundCreationMappingTests`, `RoundParticipantHandicapOverrideTests`, `HandicapComputationTests`, `SeriesRoundSyncServiceTests`, `SeriesHandicapHistoryTests`, `SeriesRoundHandicapAccrualTests`, `SeriesRoundCodableTests`, and `RoundActivationMatchupValidationTests`.

Local evidence:

- `/private/tmp/HackersPersonalHandicapEngine-final.xcresult`
- `/private/tmp/HackersPersonalHandicapEngine-final.log`
- `/private/tmp/HackersPersonalHandicapEngine-build.log`

Run each selected suite with `-only-testing:HackersUnitTests/<suite>`:

```sh
xcodebuild -project Hackers.xcodeproj -scheme Sandbox -configuration Sandbox \
  -destination 'platform=iOS Simulator,id=A868F0E8-B3F2-4B0D-9AAC-D3283A1B5806' \
  -derivedDataPath /private/tmp/HackersPersonalHandicapDerived \
  -clonedSourcePackagesDirPath /private/tmp/HackersCombinedDerived/SourcePackages \
  -disableAutomaticPackageResolution \
  -enableAddressSanitizer NO -enableCodeCoverage NO -parallel-testing-enabled NO \
  test CODE_SIGNING_ALLOWED=NO
```

Live authenticated Firebase/provider, manual UI and physical-device acceptance are not tested. Existing app-host startup Firebase permission/keychain and unpaired-watch messages still occur; selected tests pass. `git diff --check` passes. No server rules, data migrations, GitHub merges, or deployments were performed.
