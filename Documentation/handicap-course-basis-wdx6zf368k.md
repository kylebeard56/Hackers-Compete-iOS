# Course Handicap calculation — wdx6zf368k

Ticket: [Correct Handicap Index basis and Course Handicap calculation](https://app.clickup.com/t/wdx6zf368k)

Scope: Ticket 1 only. Profile management, automatic personal-versus-league selection, handicap history, and the broader round-creation redesign are deferred to their separate tickets.

## Root causes

- Series creation and sync could derive the input Index basis from the round's hole count instead of the configured league source.
- Missing tee data could round the input Index into strokes, and course/configuration changes could automatically switch Index entry to strokes.
- The same basis was used for source Index conversion and downstream stroke allocation, allowing a converted Course HCP to be scaled again.
- Calculation results did not distinguish exact segment metadata from deterministic full-course estimates. Snapshot/display code could call the capped scoring allowance the raw Course HCP.

## Implemented

- One calculation path returns EXACT, ESTIMATED, or UNAVAILABLE, with original Index, source basis, calculation-only Index, selected tee/segment, rating/slope/par provenance, unrounded result, and rounded raw Course HCP.
- Explicit source conversion: 18→9 divides by two and rounds to a tenth; 9→9 and 18→18 retain the input; 9→18 preserves doubling.
- Exact front/back/full metadata takes priority. Missing nine-hole fields use the existing deterministic Tee fallback only with applicable valid full-course data. Native nine-hole course ratings remain native nine-hole ratings.
- New round configuration stores Index basis separately from scoring-stroke basis. Series source basis comes from SeriesHandicapConfig.strokeBasis. The scoring engine and its allocation, normalization, and game-allowance algorithms are unchanged.
- Raw Course HCP is saved independently of capped effective strokes. Optional calculation/resolution fields remain compatible with old documents; no data migration runs.
- Casual setup retains entered Indexes when unavailable, exposes estimate confirmation and round-only manual strokes, and prevents starting a net round with an unresolved allowance. Consent is tied to the exact calculation inputs and is invalidated when they change.
- Existing league course-data preflight remains stricter: estimates cannot silently seed or replace league allowances. Commissioners retain the existing explicit round-only stroke override/repair paths. Frozen league snapshots and completed/archived round protections remain intact.
- Legacy integer player handicaps continue to mean strokes. An explicitly stored legacy basis remains readable; an absent source basis is not inferred from round length or presented as exact.

## Required examples

| Case | Result |
| --- | --- |
| Index 23.0, 18-hole source, back nine 34.7/124/par 36 | Calculation Index 11.5; raw Course HCP 11; original Index 23.0 |
| League Index 8.5, nine-hole source and round | Calculation Index 8.5; no second halving |
| Index 22.6, 18 holes, 73.9/143/par 72, cap 21 | Raw Course HCP 31; final allowed strokes 21; original Index 22.6 |

## Validation

Sandbox build and selected unit suites on the iOS 26.3 iPhone 17 Pro simulator: **295 tests passed, zero failures** (262 XCTest cases and 33 Swift Testing cases).

Suites: CourseHandicapCalculationRegressionTests (16 new cases), ScoringEngineTests, SeriesRoundCreationMappingTests, RoundParticipantHandicapOverrideTests, HandicapComputationTests, SeriesRoundSyncServiceTests, SeriesHandicapHistoryTests, SeriesRoundHandicapAccrualTests, SeriesRoundCodableTests, RoundActivationMatchupValidationTests. Two additional new mapping tests cover source-basis propagation and unknown basis handling.

Coverage includes all four basis conversions, front/back/full metadata, exact-versus-estimated provenance, missing tee/slope/par/basis, no Index-to-strokes fallback, confirmation and invalidation, tee recalculation, caps after raw Course HCP, manual stroke independence, registered/offline participant models, commissioner overrides, historical snapshots, legacy decoding, net scoring and stroke allocation.

Command (run from the PR checkout):

```sh
xcodebuild -project Hackers.xcodeproj -scheme Sandbox -configuration Sandbox \
  -destination 'platform=iOS Simulator,id=A868F0E8-B3F2-4B0D-9AAC-D3283A1B5806' \
  -derivedDataPath /private/tmp/HackersHandicapDerived \
  -clonedSourcePackagesDirPath /private/tmp/HackersCombinedDerived/SourcePackages \
  -disableAutomaticPackageResolution \
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
  -resultBundlePath /private/tmp/wdx6zf368k-tests-reviewed.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

`git diff --check` passes. Review specifically checked source-basis propagation through creation/sync/repair, legacy strokes initialization, commissioner editor overrides, estimate consent invalidation, and historical locks. League Index generation, eligibility, provisional rules, accrual, 0.96 multiplier, caps policy, normalization, and game allowances were not changed.

## Limits and follow-up

- No full authenticated Firebase workflow or manual UI/device acceptance run was performed; the automated tests exercise the pure model, mapping, scoring, and validation paths. App-host startup logs include existing Firebase permission/keychain and unpaired-watch messages; the selected suites pass.
- Legacy records without a configured source basis remain ambiguous. Their historical scoring allowances are retained; new calculations require an explicit basis or manual allowance.
- Series estimates remain blocked by strict course-data preflight. Use exact segment metadata or the existing commissioner-approved round-only stroke repair; casual estimate consent cannot bypass league validation.
- No historical data was migrated, no PR was merged, and no deployment was performed.

## Files modified

- `Hackers/Core/Round/RoundSession+Activate.swift`
- `Hackers/Core/Round/RoundSession+Config.swift`
- `Hackers/Core/Round/RoundSession+Course.swift`
- `Hackers/Core/Round/RoundSession+Participant.swift`
- `Hackers/Core/Scoring/ScoringService+Course.swift`
- `Hackers/Features/Round/GameLobby/Accessory/HandicapEntryView.swift`
- `Hackers/Features/Round/GameLobby/Accessory/HandicapTextField.swift`
- `Hackers/Features/Round/GameLobby/Accessory/RoundActivationErrorView.swift`
- `Hackers/Features/Round/GameLobby/GameLobby+Configuration.swift`
- `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
- `Hackers/Features/Round/GameLobby/GameLobby.swift`
- `Hackers/Features/Round/GameLobby/Player/ManagePlayerView.swift`
- `Hackers/Features/Round/RoundOutcome/IndividualScorecardView.swift`
- `Hackers/Features/Series/Services/SeriesRoundCreationMapping.swift`
- `Hackers/Features/Series/Services/SeriesRoundCreationService.swift`
- `Hackers/Features/Series/Services/SeriesRoundSyncPlanning.swift`
- `Hackers/Features/Series/Services/SeriesRoundSyncService.swift`
- `Hackers/Features/Series/Sheets/SeriesRoundDetailSheets.swift`
- `Hackers/Features/Series/ViewModels/SeriesViewModel.swift`
- `Hackers/Shared/Components/Buttons/NavButton.swift`
- `Hackers/Shared/Models/Round/Round.swift`
- `Hackers/Shared/Models/Round/RoundSnapshot.swift`
- `Hackers/Shared/Models/Round/Subcollections/Round+Participant.swift`
- `HackersUnitTests/Scoring/ScoringEngineTests.swift`
- `HackersUnitTests/SeriesRoundCreationMappingTests.swift`
- `HackersUnitTests/SeriesRoundSyncServiceTests.swift`
- `HackersUnitTests/CourseHandicapCalculationRegressionTests.swift`
- `Documentation/handicap-course-basis-wdx6zf368k.md` (this report)
