# Player Profile Handicap Management — wdx6zf65p6

Ticket: <https://app.clickup.com/t/wdx6zf65p6>

This is an independently reviewable implementation slice. **The personal calculation engine is pending explicit policy approval.** Nothing in this branch infers approval from elapsed time, creates qualifying personal scores, applies a provisional calculation, or reuses the league formula as a personal algorithm.

## Dependency and scope

PR #14 was open at inspection: `codex/wdx6zf368k-course-handicap`, commit `864af32c641f154b9be68a8fd100a73e4ce4f4cf`. This branch is stacked on that commit and targets the PR #14 branch. PR #14 is not modified or merged. The original working checkout and its unrelated changes are preserved.

The full ClickUp description, requirements, and comments were inspected (no comments, checklists, or subtasks). Existing Player Codable/persistence, profile and reusable offline-player UI, league history/projection, V1/V2 league routing, regular round creation, and PR #14 calculation and override paths were reviewed.

## Implemented independently of calculation policy

- Additive `Player.personal_handicap` record: manual decimal Index, explicit 18-hole basis, self-reported or manually entered external source, update date. Absence remains nil. Explicit 0.0 is valid. Legacy integer `Player.handicaps` stay strokes and are never converted into an Index.
- Registered owners can edit their Index. Existing reusable offline-player management permits a signed-in player to edit a persistent offline identity without a guest login. Unsaved offline drafts and other registered profiles are read-only. The existing Firestore rules are unchanged; this is an application access check, not a new server authorization policy.
- A transactional manual save re-reads the player and patches only manual/effective fields and the update date. Calculation, name, history, and unrelated fields are retained. The cached primary player is refreshed after saving, and regular creation reads a fresh primary profile.
- A policy-independent calculation-output contract persists eligibility state, version, basis, as-of date, qualifying/pool/counting references, and effective Index/source projection. The effective value is derived from a valid qualified 18-hole output, falling back to the saved manual value. Persisted effective projection fields are not read as a second authority. No calculation producer is enabled.
- Profile cards show effective, manual, and calculated values separately. The personal chart, selection/details, counters, progress state, and Counts / Pool / Unofficial history consume personal records only. Cards, fonts, palette, chart marks, date axes, and interaction styling follow the league screen. Older eligible scores outside the current pool are labeled “Earlier score.” Missing calculations show an unavailable state and unknown counts rather than a fabricated zero or threshold.
- Read-only League Handicaps uses existing routed V1/V2 discovery and `SeriesHandicapProjectionService`, including each league's overrides and explicit 9-/18-hole basis. Rows navigate to league details. No league projection or score is used as a personal Index.
- Future ordinary rounds use 18-hole personal Index entry and PR #14's canonical tee/segment calculator. Both the creating player and subsequently added registered/offline players are prefilled. Source Index/provenance and calculation resolution are captured with the participant. An unavailable Index stays nil; missing course data stays unresolved. Existing estimate consent, round-only Index/stroke edits, cap handling, lobby tee recalculation, historical provenance, and league paths remain in place.
- Round editors preserve signed Indexes (negative numeric input means a golf “plus” handicap). The scoring calculator's existing nonnegative-stroke policy is unchanged.

## Personal history storage contract

Future approved calculation publication will use the existing player document for the summary, plus:

- `players/{playerID}/personal-handicap-history/{roundID}` — player and round identity, title, played date, and full calculation output with effective-as-of date, method version, basis, and selection references.
- `players/{playerID}/personal-handicap-scores/{roundID}` — one individual score per stable round identity, played date, title, hole count, gross score, and exclusion reason.

Use the actual `Collections.players` name if it changes. History is not embedded as an unbounded array in the player document. Readers isolate player IDs, order deterministically by played date/round ID, and select the newest calculation revision before removing ineligible points. These collections are read by this slice; they are not populated by it.

## Proposed policy awaiting approval

The user was presented with these choices: approve the proposal below; approve the same algorithm with an earlier provisional Index after one 18-hole equivalent; or defer the engine and review the independent work.

Proposed initial policy:

- Minimum 54 actual completed eligible holes and three 18-hole differential equivalents. No calculated/provisional Index before qualification; use manual starting Index if supplied.
- Include complete individually attributable gross cards from ordinary or league rounds, including individual match-play/best-ball cards with every required hole scored. Require exact tee ratings, slope, par, and valid hole data. Exclude practice, unofficial, incomplete, invalid, team-only, and duplicate results. Never fill in unplayed holes.
- Differential: `(113 / slope) × (adjusted gross − course rating)`.
- Nine-hole treatment: pair chronological actual nine-hole differentials and add them; an unpaired nine waits. This is a proposed **unofficial Hackers pairing policy**, not current WHS expected-score treatment, and never doubles a nine-hole result. No unpublished expected-score formula is invented.
- Per-hole adjustment: par + 5 without a frozen input Index; otherwise net double bogey based on that round's frozen Index and uncapped Course Handicap. This affects personal calculation input only, never historical scoring.
- Latest 20 differential equivalents. Select lowest differentials per the WHS-style table: 3 → 1 minus 2.0; 4 → 1 minus 1.0; 5 → 1; 6 → 2 minus 1.0; 7–8 → 2; 9–11 → 3; 12–14 → 4; 15–16 → 5; 17–18 → 6; 19 → 7; 20 → 8. Average when more than one counts; round to one decimal; maximum 54.0. No league 0.96 multiplier.
- PCC, exceptional-score reductions, and low-index soft/hard caps are outside this proposed first-release algorithm. All generated values remain explicitly unofficial.
- Deterministically rebuild chronological results on completions, corrections, exclusions, or imports. Publish summaries/history without rewriting round participants or their frozen allowances.

Sources consulted: [USGA Rule 5.1b](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/5%201b%20Calculation%20of%20a%20Score%20Differential9Hole.htm), [USGA Rules of Handicapping](https://www.usga.org/handicapping/roh/rules-of-handicapping.html). The proposal deliberately differs from full current WHS; it must not be advertised as an official WHS/GHIN Index.

## Remaining work gated by that decision

The actual qualification threshold/algorithm tests; individual score extraction and eligibility evaluation across ordinary/league rounds; nine-hole normalization; correction/exclusion/import reconciliation; duplicate-safe publication; automatic score-event recalculation; and population of calculated summaries/history. The effective-source transition and chart reader can consume approved outputs but are not proof of a working score calculation engine.

## Validation

The Sandbox simulator build passed. The available iPhone 17 Pro simulator (iOS 26.3.1) passed **322 tests, 0 failed, 0 skipped**, confirmed with `xcresulttool get test-results summary`. This includes **27 new personal-profile tests**, 289 XCTest cases overall, and 33 Swift Testing cases.

The new tests cover manual encoding/reload and edits, explicit zero versus absence, registered/offline identity and edit access, retention of manual and calculated records, effective-source transition from qualified output, loss of eligibility, legacy integer compatibility, plus-handicap entry, explicit 18-hole basis, ordinary round prefill, canonical nine-/18-hole Course HCP conversion, unavailable tee data, tee recalculation with preserved input, round-only override isolation, historical participant snapshots, league/strokes-mode isolation, chronological chart ordering, correction invalidation, duplicate chart records, and score-history statuses. Transition/history tests exercise the output contract; they do **not** claim that the pending calculation engine exists or that its policy has been approved.

Existing selected suites: `CourseHandicapCalculationRegressionTests`, `ScoringEngineTests`, `SeriesRoundCreationMappingTests`, `RoundParticipantHandicapOverrideTests`, `HandicapComputationTests`, `SeriesRoundSyncServiceTests`, `SeriesHandicapHistoryTests`, `SeriesRoundHandicapAccrualTests`, `SeriesRoundCodableTests`, and `RoundActivationMatchupValidationTests`.

```sh
xcodebuild -project Hackers.xcodeproj -scheme Sandbox -configuration Sandbox \
  -destination 'platform=iOS Simulator,id=A868F0E8-B3F2-4B0D-9AAC-D3283A1B5806' \
  -derivedDataPath /private/tmp/HackersPersonalHandicapDerived \
  -clonedSourcePackagesDirPath /private/tmp/HackersCombinedDerived/SourcePackages \
  -disableAutomaticPackageResolution \
  -only-testing:HackersUnitTests/PersonalHandicapProfileTests \
  -only-testing:HackersUnitTests/CourseHandicapCalculationRegressionTests \
  -only-testing:HackersUnitTests/ScoringEngineTests \
  -only-testing:HackersUnitTests/SeriesRoundCreationMappingTests \
  -only-testing:HackersUnitTests/RoundParticipantHandicapOverrideTests \
  -only-testing:HackersUnitTests/HandicapComputationTests \
  -only-testing:HackersUnitTests/SeriesRoundSyncServiceTests \
  -only-testing:HackersUnitTests/SeriesHandicapHistoryTests \
  -only-testing:HackersUnitTests/SeriesRoundHandicapAccrualTests \
  -only-testing:HackersUnitTests/SeriesRoundCodableTests \
  -only-testing:HackersUnitTests/RoundActivationMatchupValidationTests \
  -enableAddressSanitizer NO -enableCodeCoverage NO -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/HackersPersonalHandicap-tests.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

`git diff --check` passes. Live authenticated Firebase transaction/save/reload, deployed rule enforcement, manual simulator UI acceptance, and physical-device testing have not been exercised. App-host startup emitted existing Firebase permission/installation and unpaired-watch errors; they did not fail the selected tests. League discovery inherits the existing routed discovery helpers' error handling; no server authorization changes are included. Actual score eligibility, differential generation, nine-hole pairing/expected scores, automatic completion/correction/exclusion recalculation, and history publication await approved policy and remain untested because this slice does not implement them.
