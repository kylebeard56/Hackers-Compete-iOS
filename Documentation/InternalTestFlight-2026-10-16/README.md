# Internal TestFlight readiness — 2026-10-16

**Release decision: BLOCKED. No combined build was archived, uploaded, distributed externally, or published. Do not install an unvalidated combined candidate for the next round.**

## Included code and synchronization

| PR | Included commits | Result |
| --- | --- | --- |
| #14 Course Handicap | `864af32c641f154b9be68a8fd100a73e4ce4f4cf` | Preserved unchanged, still open against main. |
| #15 Personal Index and nine-hole calculations | `51f98a4a`, then reliability fixes `df7805a3` and `0fc3aa13` | Latest source head `0fc3aa13f72538912139246264e8be48460a1912`; draft. |
| #16 Setup entry and keyboard dismissal | `b3faed3e`, merges `a88a9a07` and `8524cd40` | Includes latest #15 and #14 without rewriting either history; draft. |

Both merges completed without conflicts. Ancestry checks confirm the required original commits are retained. Main was not merged or modified. Unrelated dirty/untracked files in the primary checkout were excluded.

## Reliability fixes

`RoundSession.addPlayers` now refreshes personal history on a best-effort, per-player basis. A disconnected network, timeout, permission/read failure, or absent result retains the saved personal profile and continues processing players. Successful refresh replaces only matching personal-profile data, preserving player identity and legacy integer allowances. The existing prefill chooses saved calculated/manual Indexes and their source/date. An integer stroke allowance never becomes an Index; missing personal input stays unresolved. League setup and frozen round participants are excluded.

The primary-player path in `CourseSelectionViewModel.createRoundLobby` had the same optional-history dependency. It now continues with the saved profile on refresh failure. Net activation still requires valid resolution through the existing guard. Required round/player database writes can still fail when the entire network is unavailable; this fix removes the unnecessary history-refresh dependency, not the need to persist a new round.

Ten regressions cover registered and reusable offline players, last saved calculated/manual values, source/date preservation, network/permission/timeouts, missing/legacy-only data, per-player continuation, success, empty results, league exclusion, completed snapshots, and primary-player lobby refresh. No handicap formulas, Wolf rules, league algorithms, or historical participant allowances were changed.

## Confirmed release blockers

1. **Plus personal Index becomes scratch in actual net scoring.** On rating 72, slope 113, par 72, personal Index -2 correctly produces raw Course Handicap -2, but `allowedStrokes` clamps it to zero and the allocation functions return zero instead of the negative stroke. Reproduced against combined code: adjusted handicap expected -2, actual 0; stroke on stroke-index 18 expected -1, actual 0. See `CourseHandicapCalculation.allowedStrokes` and `ScoringEngine.strokesReceived`. This affects net results and fails the scoring release criterion. [USGA Appendix C](https://www.usga.org/content/usga/home-page/handicapping/roh/Content/rules/Appendix%20C%20Handicap%20Allowances.htm) explicitly allocates plus-two strokes back at stroke indexes 18 and 17.
2. **Re-saving a manual Index changes unchanged historical personal calculations.** For three complete individual league cards with gross 10 on every hole, re-saving the same manual Index 10 at a later date removes its as-of-play fallback. Reproduced adjusted gross **118 → 162**, calculated personal Index **44.0 → 54.0**, and historical `personalIndexAtPlay` **10 → nil**, with no score changes. The replay reads only the current dated manual record. Fixing only an unchanged Save would not address real manual edits losing prior historical inputs. Frozen round allowances were not rewritten by this release patch, but personal history/calculated results are incorrect on refresh.
3. **Course repository regression suite remains red.** Ten existing cases fail across cached detail/search, legacy recovery, tee identity, and summary selection. Several fixtures have incomplete scorecards while current code requires playable tee data; one search expectation conflicts with substring matching. These need reconciliation and a passing course/tee acceptance check before release. The test failures are confirmed; they are not all independently established production defects. Course logic was left unchanged.

The two scoring/history reproducers are preserved in `InternalReleaseBlockerAuditTests.swift` beside this report. They were temporarily included in the unit-test target for the isolated gate run, then moved here so their intentionally failing assertions do not silently contaminate routine CI. **Moving them is not a fix or a release waiver.** Copy that file into `HackersUnitTests`, run `-only-testing:HackersUnitTests/InternalReleaseBlockerAuditTests`, and remove the temporary copy afterward to reproduce. Both must pass before upload.

## Automated validation

- PR #15 initial fix: **103 passed, 0 failed, 0 skipped**, `/private/tmp/hackers-release-pr15-refresh.xcresult`.
- PR #15 final lobby/player fix: **115 passed, 0 failed, 0 skipped** (10 reliability, 68 personal calculation, 27 profile, 10 course-selection cases), `/private/tmp/hackers-release-pr15-lobby-refresh.xcresult`.
- Combined focused release gate: **146 passed, 2 failed, 0 skipped**, `/private/tmp/hackers-internal-release-gate.xcresult`. The failures are the two confirmed blockers above. The passing cases include all 11 hosted keyboard regressions, 17 setup-entry cases, all 115 final #15 cases, and three new score-preservation/resume integrations.
- Final complete suite: **964 passed, 10 failed, 5 skipped** (979 total), `/private/tmp/hackers-internal-combined-final.xcresult`. All 874 XCTest cases passed; the failures are the ten existing Swift Testing course repository cases. The corrected resume fixtures and all other tested code paths passed. The isolated two-test scoring/history audit is recorded separately above and remains a release blocker.
- **Clean Sandbox simulator build passed** after `xcodebuild clean`; app installed/launched and the sign-in screen was visually confirmed. Build log: `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_run_sim_2026-10-16T10-05-03-672Z_pid36428_3e3052c0.log`. Launch proof: `/var/folders/lv/l852tplx755dks4wvkz1f5mr0000gn/T/screenshot_optimized_21a78d1a-b109-4487-b743-f6c5a3f56758.jpg`.
- `git diff --check` passes.

The five skipped cases are existing OCR/chat/live-course diagnostic or preview cases; they are not claimed as passed.

Tests ran on iPhone 17 Pro / iOS 26.3.1. The 68 personal calculation tests cover the latest nine-hole pairing/expected-nine model, chronological rebuilds, exclusions/corrections, and score history. The full suite covers scoring, team formats, leagues, snapshots, lifecycle/readiness, and live-round projections. PR #15’s expected-nine conversion remains the approved unofficial Hackers approximation, not an official USGA/GHIN calculation or certification of parity.

## Requested flow coverage and limits

| Flow | Evidence / remaining limit |
| --- | --- |
| Nine- and eighteen-hole setup | Automated course-selection/configuration, prefill and calculator fixtures; no signed-in device round-creation acceptance. |
| Course and tees | Course-selection tests pass; ten repository/search/cache/tee tests fail. Release blocked. |
| Registered/offline players | Injected refresh failures and successes preserve saved inputs; authenticated participant batch writes not exercised. Offline player means reusable guest identity; fully disconnected new-round writes are not promised. |
| Index / Strokes Received and keypad | Both modes in HandicapEntryView, ManagePlayerView, and actual roster field/dismiss control; accessible 44-point Done, real UIKit text input/keyboard-hide events, preservation and no dismissal save/navigation. Roster uses a local host, not a signed-in end-to-end lobby. |
| Course Handicap and allocation | Existing positive/basis/cap regressions pass; signed plus-handicap scoring fails as above. |
| Gross/net display, scorecard and leaderboard | Automated model/projection/scoring cases; no full manual device acceptance. |
| Hole-by-hole entry and existing-score preservation | Engine/projection tests plus three local integrations for nine/front/back/eighteen-hole navigation, durable resume, repeated hydration and retained score lookup. Authenticated remote write/reload/concurrency not tested. |
| Background/lock/reopen/current hole | Durable UserDefaults/new AppSession and listener hydration tested; existing seven resume regressions pass. Real OS lock/unlock and physical-device suspension remain outstanding. |
| Wolf/team/league | Rules unchanged; existing team/league regression suites run. No dedicated Wolf test or manual Wolf round was found/executed; no claim of a Wolf playthrough. |

## Signing, version and TestFlight

Existing Sandbox scheme/configuration uses automatic signing for team `28EF5GR4R6`, bundle `com.tigermindlabs.hackers.compete.sandbox`, marketing version **1.0.0**, with watch/live-activity companion targets. The checked-in build number is `2026.09.15.1`; the established workflow overrides it per upload. App Store Connect authentication using the existing deployment helper succeeded. This does not certify a new archive's signing/provisioning.

The previous **Hackers Compete Test** build **1.0.0 (2026.10.15.1)** is `VALID` / `IN_BETA_TESTING` as checked on October 16. It predates the combined code and is not the result of this work. Internal group **Beta** has access to all builds. External group **Beta Testers** exists; it was not modified.

The Fastlane lane enables external distribution by default and was not used. Internal-only Xcode export options were prepared with `testFlightInternalTestingOnly=true` and automatic version management disabled. Installed Xcode documents that this flag disallows external TestFlight and App Store distribution; Apple also describes [internal-only distribution](https://developer.apple.com/tutorials/develop-in-swift/test-your-beta-app). No upload/export command was executed. No new build number was allocated, no signed release archive/IPA was created, and no new processing/tester-availability result exists. App Store Connect reads authenticated; validation stopped the release before new archive signing or upload authentication was tested.

Before retrying: resolve the two scoring/history blockers without changing Wolf/league policy or frozen round data; reconcile the ten course repository failures; rerun those isolated reproducers, the complete suite and clean simulator build; perform signed-in course/tee/round/scoring and lock/reopen smoke acceptance. Then allocate a build number newer than App Store Connect, archive the validated commit using the existing Sandbox configuration, and export/upload with `testFlightInternalTestingOnly=true`. Verify `VALID`, internal `IN_BETA_TESTING`, internal group access and no external group assignment. Do not merge to main or submit App Store/external beta review.

**Install-and-play answer: No new combined build is ready. Release remains blocked.** Physical-device and authenticated Firebase concurrency checks remain outstanding and were not claimed as passed.

## Full-suite reproduction

From the combined checkout, use a fresh result-bundle path:

```sh
xcodebuild -project Hackers.xcodeproj -scheme Sandbox -configuration Sandbox \
  -destination 'platform=iOS Simulator,id=A868F0E8-B3F2-4B0D-9AAC-D3283A1B5806' \
  -derivedDataPath /private/tmp/HackersEntryDerived \
  -clonedSourcePackagesDirPath /private/tmp/HackersCombinedDerived/SourcePackages \
  -disableAutomaticPackageResolution -enableAddressSanitizer NO \
  -enableCodeCoverage NO -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/hackers-internal-combined-recheck.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

The isolated scoring/history reproducers are deliberately separate from this complete routine-suite count. Their two failures are additional evidence against release, not waived by the routine-suite result.
