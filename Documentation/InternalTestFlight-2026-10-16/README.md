# Internal TestFlight release — October 16, 2026

**PR #14–16 critical automated gates and clean simulator build pass. PR #17 has now been requested for this release; integration and renewed combined validation are pending. The superseded archive was stopped before upload. No installation availability is claimed yet.**

## Included code

The release candidate comes from the existing PR #16 worktree and branch `codex/wdx6zf3848-handicap-entry`. It retains PR #14 at `864af32c641f154b9be68a8fd100a73e4ce4f4cf`, PR #15 through `0fc3aa13f72538912139246264e8be48460a1912` (including `51f98a4a` and the player/lobby refresh fixes), and PR #16's keyboard work including `b3faed3e`. The dependency merges remain `a88a9a07` and `8524cd40`. Main was not merged or modified. No production services were deployed.

Validated code commit: **`9f3b2517681353c7e2e8e46a7aec0608d2c15c36`**. Subsequent report-only commits do not change the archived app code.

## Release blockers fixed

Signed Course Handicaps now survive the allowed-strokes cap and allocation pipeline. A Course Handicap of **-2** gives one stroke back on stroke-index **18** and **17**. Net scoring adds those strokes while gross scores remain unchanged. Nine-hole basis scaling retains the sign. Relative handicap normalization subtracts the signed lowest handicap; positive calculations and upper caps retain their existing behavior. No Wolf rules or league handicap policy changed.

An unchanged manual Index save is a no-op that preserves its original effective date and provenance. Actual edits and clears now retain dated profile input revisions. Historical personal recalculation selects the manual/external input applicable at play time, after existing frozen-input and chronological calculated-history precedence. The Firestore transaction patches the profile revision history atomically with the current input and preserves concurrent unrelated fields. Completed scorecards and frozen participant allowances are never rewritten by this change. Legacy profiles decode without history; their current dated manual record seeds the first edit. Inputs already erased by an older app before this history existed cannot be reconstructed automatically.

Both original failing audit reproducers are now permanent tests in `HackersUnitTests/InternalReleaseBlockerAuditTests.swift`, alongside signed allocation, caps, gross/net, actual edits, clears, source changes, Codable and older-client compatibility checks. They are part of the normal full suite, not an isolated waived gate.

The prior player-setup reliability fixes remain included: optional personal-history refresh failures retain valid saved personal input and permit adding players/lobby creation to proceed. Legacy integer allowances never become personal Indexes, missing data stays unresolved, and league/frozen inputs remain excluded. Required database writes still require connectivity.

## Investigation of all ten course failures

| Previously failing test | Finding and resolution |
| --- | --- |
| `cacheHitAvoidsRemoteRequest` | Fixture claimed a playable cache hit but had no tees. Added a valid full/nine-rated 18-hole tee; the scorecard guard remains. |
| `cachedSearchAvoidsRemoteRequest` | Shared provider fixture had no scorecard. Added playable tee data; cached search still avoids the remote. |
| `cacheMissFetchesAndCachesRemoteCourse` | Incomplete detail fixture and retired numeric-ID expectation. Use a current opaque provider ID and playable data; await the existing asynchronous cache write. |
| `deterministicGolfCourseAPIIdentity` | Obsolete expectation rejected “Club” despite intentional token-prefix search. Assert the match and retain an unrelated-query rejection. |
| `legacyCacheRecovery` | Incomplete legacy fixture could not satisfy current playable-scorecard requirements. Supply valid cached tee data; verify no retired endpoint call. |
| `legacySearchAndDetailAgree` | **Production defect:** cached detail skipped the canonicalization already used by search. Canonicalize cached provider course/tee identity before use, retaining holes, ratings and slopes. |
| `scorecardSearchLoadsDetail` | Incomplete detail fixture. Resolve actual playable data; await persistence and assert a complete card without imposing background-task order. |
| `searchRejectsNonProviderCacheRecords` | **Production defect:** provider compatibility search could reinterpret a saved manual course carrying a stray provider ID. Require provider origin. The main library still returns the saved manual course; external search remains an explicit action. |
| `selectSearchSummaryLoadsDetail` | Incomplete shared detail fixture correctly prevented selection. A playable fixture now verifies selection; the separate empty-scorecard rejection still passes. |
| `successfulSearchCachesAllResults` | Shared detail fixtures were incomplete and persistence assertions raced background saves. Supply playable data and await completion. |

Additional summary-cache expectations now reflect the existing directory/scorecard distinction: directory metadata may be cached without fetching all details or pretending it is playable. No tests were disabled or newly skipped. All course repository tests now pass. No unrelated course failure remains outstanding.

## Validation evidence

- Focused release run: **248 passed, 0 failed, 0 skipped**; `/private/tmp/hackers-release-focused-final.xcresult`. Includes all nine blocker regressions, all eleven hosted keyboard checks and the live course-provider diagnostic.
- Full suite: **983 passed, 0 failed, 5 skipped** (988 total); `/private/tmp/hackers-release-full-fixed.xcresult`.
- Earlier focused fix run: **219 passed, 0 failed, 0 skipped**; `/private/tmp/hackers-release-blockers-fixed-1.xcresult`.
- `git diff --check` passes.
- Clean simulator build **passed** after clean; installed and launched to sign-in. Log: `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_run_sim_2026-10-16T10-43-31-034Z_pid36428_7187329f.log`. Screenshot: `/var/folders/lv/l852tplx755dks4wvkz1f5mr0000gn/T/screenshot_optimized_7a2ff3a3-b005-405d-8dae-acb02e09094c.jpg`.

The standard five skipped cases are existing opt-in OCR/chat/live-course diagnostics or previews, not passed tests. The live provider diagnostic was separately enabled and passed: search returned two Verdae matches and current opaque ID `xnmmcgzp` loaded eight tees, including an 18-hole scorecard. This verifies the course service, not signed-in Firebase writes.

Simulator: iPhone 17 Pro, iOS 26.3.1, Sandbox configuration. The full suite exercises positive and signed allocation, caps, 9/18-hole course setup, personal calculation/history, registered/reusable guest prefill, league/team scoring and snapshots. The three local resume integrations verify nine/front/back/eighteen-hole navigation, previously entered scores, durable current-hole restoration through a new AppSession, and repeated listener hydration without default-score overwrites.

All 11 hosted keyboard regressions cover HandicapEntryView, ManagePlayerView and the actual roster input/dismiss control in both Handicap Index and Strokes Received modes. Done is visible and accessible with a 44-point target, closes actual UIKit numeric-keyboard focus, preserves the value, and does not trigger a save, navigation or clear. The roster's existing edit-driven debounce remains separate from dismissal. Ticket **wdx6zf0n03 is complete in PR #16** within this tested setup scope.

Gross/net score projections, scorecard and leaderboard have automated coverage. No dedicated manual Wolf round was played; its rules were not modified. The personal expected-nine conversion remains the existing unofficial Hackers approximation, not USGA/GHIN certification.

Existing compiler warnings remain, including recursive helper branches in `ModifierApplicator` for the unused `allPlayersMatch` predicate and the unused coordinate `distance(to:)` extension. Repository search found no shipped template or UI construction of that predicate and no callers of the coordinate extension; active course distance paths use CLLocation. They were not changed as part of this release. Custom/remote pipelines using that unsupported predicate are not covered by this internal acceptance. Existing Swift 6 migration warnings also remain; this candidate builds in the established Swift language mode.

## Smoke-test limits

The clean simulator app launches to sign-in. No signed-in app credentials were available, so authenticated Firebase round creation/write/reload, real concurrent-device scoring and a signed-in end-to-end course/tee/round smoke test were not performed. `xcrun devicectl list devices` returned **No devices found**; physical-device scoring, OS lock/unlock and real suspension acceptance remain outstanding. The durable resume/hydration tests are local integrations and do not claim those device checks passed. These limits are disclosed for internal testing; there are no remaining known critical scoring/history failures in the executed release checks.

## Signing and internal distribution

Planned candidate: **1.0.0 (2026.10.16.1)**. Previous latest Apple build is 2026.10.15.1. The PR #14–16 archive was stopped when PR #17 was added to scope. A fresh archive/upload/processing are pending after renewed validation. Internal group **Beta** has access to all builds; no external distribution is requested.

The Sandbox app is **Hackers Compete Test**, bundle `com.tigermindlabs.hackers.compete.sandbox`, App Store Connect ID `6757443901`, team `28EF5GR4R6`. The established workflow overrides `CURRENT_PROJECT_VERSION` for the app and companion targets. The Fastlane lane enables external testing by default and was not used. Export/upload uses Xcode `app-store-connect`, automatic signing, `manageAppVersionAndBuildNumber=false`, and **`testFlightInternalTestingOnly=true`**. No external group assignment, beta/App Store review submission or main merge is authorized or performed.

**Install-and-play: pending archive, upload and Apple processing.**

## Reproduction

Run the normal full unit suite from the PR #16 worktree with a fresh result path:

```sh
xcodebuild -project Hackers.xcodeproj -scheme Sandbox -configuration Sandbox \
  -destination 'platform=iOS Simulator,id=A868F0E8-B3F2-4B0D-9AAC-D3283A1B5806' \
  -derivedDataPath /private/tmp/HackersEntryDerived \
  -clonedSourcePackagesDirPath /private/tmp/HackersCombinedDerived/SourcePackages \
  -disableAutomaticPackageResolution -enableAddressSanitizer NO \
  -enableCodeCoverage NO -parallel-testing-enabled NO \
  -resultBundlePath /private/tmp/hackers-release-recheck.xcresult \
  test CODE_SIGNING_ALLOWED=NO
```

For the live provider diagnostic, include `-only-testing:HackersUnitTests/GolfCourseAPILiveDiagnosticTests` and set `TEST_RUNNER_RUN_LIVE_GOLFCOURSE_API_TEST=1` in the invoking environment.
