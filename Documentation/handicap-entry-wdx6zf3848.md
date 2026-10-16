# Round setup handicap entry — wdx6zf3848

Ticket: [Allow Strokes or Handicap Index entry during round creation](https://app.clickup.com/t/wdx6zf3848).

## Dependency review and scope

Reviewed the complete ticket including its October 14 additions, its empty comment thread, and [source-resolution ticket wdx6zf65p7](https://app.clickup.com/t/wdx6zf65p7). At implementation start, PR #14 was open at `864af32c`; PR #15 was draft/open at `3270ae59`, stacked on #14. During validation, PR #15 advanced to `d5077c21`; this ticket was rebased onto that update and its new personal refresh path was reused for mode-switch prefill. This ticket uses its own branch/worktree and targets PR #15's branch, `codex/wdx6zf65p6-player-profile-handicap`. Neither dependency branch is changed.

PR #14 already implements the basis-aware calculator, raw Course HCP separate from allowed strokes, Exact/Estimated/Unavailable results, estimate consent, per-participant manual recovery, activation validation, and frozen league snapshots. PR #15 already implements effective personal Index storage and ordinary-round participant prefill. This PR reuses those paths.

Source-resolution ticket wdx6zf65p7 remains in backlog. Automatic personal Index fallback for new league members and the later transition to an established league Index remain dependent on that ticket. No new league eligibility or source-priority rules are introduced here. PR #15 now supplies saved manual and available unofficial calculated personal Indexes. Its missing numeric expected-score inputs for nine-hole/partial personal calculation remain a dependency limitation. This entry flow uses the effective 18-hole personal Index exposed by PR #15 and does not introduce another personal calculation policy.

## User-facing behavior

- Handicap-enabled lobby configuration shows a visible, two-option Handicap Index / Strokes Received picker using `HandicapEntryFormat`. League configurations remain locked; advanced normalization and basis options retain their existing menu.
- Index entry accepts one decimal place, preserves the Index, and shows raw Course HCP separately from capped strokes. Personal and league sources are labeled using existing provenance.
- Switching an existing ordinary round to Index entry attempts personal prefill through PR #15's helper, including registered and reusable guest profiles. Missing profiles remain unresolved for explicit entry. Previously entered Indexes are not overwritten by profile refreshes.
- In Index rounds, a player can explicitly switch to manual round-only strokes and return to the original Index. Separate editor buffers and an optional field in the existing per-participant resolution preserve explicit manual input across mode changes. No calculated Course HCP is silently adopted as a manual input.
- Course/tee/segment changes continue through PR #14's calculator. Manual allowances remain independent; unavailable data never changes the round format or another participant's entry.
- Existing estimate consent is recognized when reopening an editor. Input changes invalidate consent through PR #14's calculation equality. The lobby passes the existing user ID to record the approver.
- Unavailable results identify missing metadata and expose course-data repair and explicit manual strokes. Unresolved stroke input displays a dash/prompt instead of a stale allowance.
- Keyboard dismissal preserves editor buffers. Blank/partial input does not invent zero; decimal text pasted into whole-number stroke entry is rejected. Commissioner override confirmation and restore remain available through the existing paths.

No changes to live score-entry keypads, league Index computation, normalization algorithms, game allowances, historical records, or saved personal/league handicap writes.

## Validation

Before the keyboard-dismissal follow-up below, **390 tests passed, 0 failed, 0 skipped**, confirmed with `xcresulttool`, on iPhone 17 Pro / iOS 26.3.1. The final test run rebuilt the simulator app against PR #15 at `d5077c21`. A separate Sandbox simulator build also passed before the dependency update. `git diff --check` passes.

Result bundle: `/private/tmp/wdx6zf3848-current-base.xcresult`. Seventeen new tests are in this ticket; the remaining tests exercise existing/dependency behavior.

Reproducible test command (use a fresh result bundle path when repeating):

```sh
xcodebuild -project Hackers.xcodeproj -scheme Sandbox -configuration Sandbox \
  -destination 'platform=iOS Simulator,id=A868F0E8-B3F2-4B0D-9AAC-D3283A1B5806' \
  -derivedDataPath /private/tmp/HackersEntryDerived \
  -clonedSourcePackagesDirPath /private/tmp/HackersCombinedDerived/SourcePackages \
  -disableAutomaticPackageResolution \
  -only-testing:HackersUnitTests/RoundHandicapEntryTests \
  -only-testing:HackersUnitTests/PersonalHandicapProfileTests \
  -only-testing:HackersUnitTests/PersonalHandicapCalculationTests \
  -only-testing:HackersUnitTests/CourseHandicapCalculationRegressionTests \
  -only-testing:HackersUnitTests/ScoringEngineTests \
  -only-testing:HackersUnitTests/SeriesRoundCreationMappingTests \
  -only-testing:HackersUnitTests/RoundParticipantHandicapOverrideTests \
  -only-testing:HackersUnitTests/RoundManagementAccessTests \
  -only-testing:HackersUnitTests/HandicapComputationTests \
  -only-testing:HackersUnitTests/SeriesRoundSyncServiceTests \
  -only-testing:HackersUnitTests/SeriesHandicapHistoryTests \
  -only-testing:HackersUnitTests/SeriesRoundHandicapAccrualTests \
  -only-testing:HackersUnitTests/SeriesRoundCodableTests \
  -only-testing:HackersUnitTests/RoundActivationMatchupValidationTests \
  -enableAddressSanitizer NO -enableCodeCoverage NO -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/wdx6zf3848-current-base.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

Seventeen new `RoundHandicapEntryTests` cover mode labels and binding in a hosted SwiftUI mobile-width picker, separate input buffers, decimal/whole-number validation, cap separation, mode switching and round-only persistence, personal prefill after players are added, absent personal Index, independent missing-tee state, 18-to-9 conversion and course changes, estimate consent/reopening/invalidation, frozen nine-hole league snapshots, and legacy resolution decoding/manual-stroke recovery. The picker test attaches a rendered image to the result bundle.

Existing selected suites cover personal profile prefill and historical preservation; all four 9/18-hole basis combinations; gross/net scoring and stroke allocation; commissioner authorization and overrides; league creation/sync; computation, history, accrual, Codable snapshots; and round activation.

Authenticated Firebase end-to-end workflows and physical-device acceptance were not exercised. The hosted picker test checks its labels and binding; it is not a full lobby UI automation test. Existing unrelated compiler warnings are retained.

## Keyboard dismissal follow-up — wdx6zf0n03

Reviewed [Add clear dismiss action to stroke-entry keypad](https://app.clickup.com/t/wdx6zf0n03) against draft PR #16. This ticket concerns per-player round-setup input; live hole-by-hole gross scoring is outside its scope.

The existing sheet keyboard toolbar was not exposed when the editor was hosted without a navigation container: a hosted UI reproducer failed to find Done before the fix. The roster already had a dismissal action, but its icon lacked a clear accessible label, and focus loss also submitted the input. Those confirmed gaps are fixed by replacing the existing controls with a shared, visible Done button (minimum 44-point height, keyboard-dismiss symbol, accessibility label and hint). The sheets use a keyboard-aware bottom safe-area inset; the lobby reuses its existing focused footer. There is one dismissal control per path.

Done only releases focus. Sheet Save/Update actions stay separate. Roster input retains autosave through the existing debounce utility, driven by the edit rather than focus loss. Pending input stays visible until the model acknowledges it; empty input submits nothing, explicit zero still resolves pending strokes, and changing entry mode cancels an edit pending in the previous mode. No handicap calculation or scoring code changed in this follow-up.

| Entry path | Handicap Index | Strokes Received | Dismissal side effects |
| --- | --- | --- | --- |
| HandicapEntryView | Passed | Passed | Numeric keyboard hides; draft remains; no Save or editor dismissal; subsequent explicit Save receives the draft. |
| ManagePlayerView | Passed | Passed | Numeric keyboard hides; draft remains; participant/round snapshot unchanged; no Update or navigation. |
| Game Lobby roster field and footer control | Passed | Passed | Numeric keyboard hides; entered value remains; Done submits no edit and does not navigate; edit-driven autosave occurs once. |

Validation: **37 focused tests passed, 0 failed, 0 skipped** on iPhone 17 Pro / iOS 26.3.1, rebuilding the Sandbox simulator app. This includes **11 new hosted UI regression tests**, the existing 17 entry tests, four participant override tests, and five management-access tests. `git diff --check` passes. The earlier 390-test baseline was not rerun for this UI-only follow-up.

The hosted UI tests use real SwiftUI editors and backing UIKit numeric text fields, activate Done through accessibility, check the button frame and 44-point target, and observe system keyboard-hide notifications. They cover both modes in all three paths, immediate dismissal before debounce, blank input, explicit zero, and a mode change while an Index edit is pending. Screenshots are attached to `/private/tmp/wdx6zf0n03-acceptance.xcresult`. The roster test hosts its actual field and shared footer control in a local harness; it does not run a signed-in Firebase lobby end-to-end. Physical devices and Android/mobile web were not exercised; this repository is the iOS implementation.

Reproduce the follow-up using the simulator command above, replacing its suite selections with:

```sh
-only-testing:HackersUnitTests/HandicapKeyboardDismissalTests \
-only-testing:HackersUnitTests/RoundHandicapEntryTests \
-only-testing:HackersUnitTests/RoundParticipantHandicapOverrideTests \
-only-testing:HackersUnitTests/RoundManagementAccessTests
```

Use a fresh result bundle path, such as `/private/tmp/wdx6zf0n03-acceptance.xcresult`. Ticket **wdx6zf0n03 can be considered complete for iOS as part of PR #16** with these changes. Source-resolution ticket wdx6zf65p7 remains a separate dependency of the broader entry work. No merge or deployment.

## Files changed

- `Hackers/Core/Round/RoundSession+Config.swift`
- `Hackers/Core/Scoring/ScoringService+Course.swift`
- `Hackers/Features/Round/GameLobby/Accessory/HandicapEntryView.swift`
- `Hackers/Features/Round/GameLobby/Accessory/HandicapTextField.swift`
- `Hackers/Features/Round/GameLobby/GameLobby+Configuration.swift`
- `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
- `Hackers/Features/Round/GameLobby/GameLobby.swift`
- `Hackers/Features/Round/GameLobby/Player/ManagePlayerView.swift`
- `Hackers/Shared/Components/Buttons/NavButton.swift`
- `Hackers/Shared/Models/Player/PersonalHandicap.swift`
- `Hackers/Shared/Models/Round/Round.swift`
- `Hackers/Shared/Models/Round/Subcollections/Round+Participant.swift`
- `HackersUnitTests/RoundHandicapEntryTests.swift`
- `HackersUnitTests/HandicapKeyboardDismissalTests.swift`
- `Documentation/handicap-entry-wdx6zf3848.md` (this report)

No merge, data migration, or deployment.
