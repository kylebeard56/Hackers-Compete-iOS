# Internal TestFlight release — October 16, 2026

**Both Hackers Compete and Hackers Compete Test 1.0.0 (2026.10.16.1) are processed, internal-only, and available to their internal Beta groups. All critical executed scoring/history/course checks pass. Physical-device and signed-in Firebase smoke limits remain disclosed below.**

## Included code

The release candidate comes from the existing PR #16 worktree and branch `codex/wdx6zf3848-handicap-entry`. It retains PR #14 at `864af32c641f154b9be68a8fd100a73e4ce4f4cf`, PR #15 through `0fc3aa13f72538912139246264e8be48460a1912` (including `51f98a4a` and the player/lobby refresh fixes), and PR #16's keyboard work including `b3faed3e`. The dependency merges remain `a88a9a07` and `8524cd40`. Main was not merged or modified. No production services were deployed.

The scoring/history/course fixes are in **`9f3b2517681353c7e2e8e46a7aec0608d2c15c36`**. PR #17 source head **`be001f41cdd4a33c05068d094b7c8af9ebc9bc00`** is included through cherry-picks **`d1e90f34`** (source `32986986`) and **`e01763d9`** (source `be001f41`). Its two commits were applied to this branch without incorporating unrelated newer-main commits. The sole profile-layout conflict retained Settings directly under the profile/name card and the complete personal Handicap section. Final app-code candidate: **`9459c7170733767bb572c8eeba242624cb9d3b2a`**. Documentation/CI-only commits after it do not alter the app code.

## Release blockers fixed

Signed Course Handicaps now survive the allowed-strokes cap and allocation pipeline. A Course Handicap of **-2** gives one stroke back on stroke-index **18** and **17**. Net scoring adds those strokes while gross scores remain unchanged. Nine-hole basis scaling retains the sign. Relative handicap normalization subtracts the signed lowest handicap; positive calculations and upper caps retain their existing behavior. No Wolf rules or league handicap policy changed.

An unchanged manual Index save is a no-op that preserves its original effective date and provenance. Actual edits and clears now retain dated profile input revisions. Historical personal recalculation selects the manual/external input applicable at play time, after existing frozen-input and chronological calculated-history precedence. The Firestore transaction patches the profile revision history atomically with the current input and preserves concurrent unrelated fields. Completed scorecards and frozen participant allowances are never rewritten by this change. Legacy profiles decode without history; their current dated manual record seeds the first edit. Inputs already erased by an older app before this history existed cannot be reconstructed automatically.

Both original failing audit reproducers are now permanent tests in `HackersUnitTests/InternalReleaseBlockerAuditTests.swift`, alongside signed allocation, caps, gross/net, actual edits, clears, source changes, Codable and older-client compatibility checks. They are part of the normal full suite, not an isolated waived gate.

The prior player-setup reliability fixes remain included: optional personal-history refresh failures retain valid saved personal input and permit adding players/lobby creation to proceed. Legacy integer allowances never become personal Indexes, missing data stays unresolved, and league/frozen inputs remain excluded. Required database writes still require connectivity.

PR #17 adds independent, account-scoped local **Apple Watch** and **Live Activities** settings, both default OFF, while keeping iPhone scoring and resume independent. Turning a companion off cancels its publication/listeners; Watch score edits are rejected when disabled. Paired Watch delivery, actual Lock Screen/Dynamic Island presentation and signed-in flows still require device acceptance. See `Documentation/user-settings.md` for standalone PR evidence.

Its report identified an existing untracked scoring audit. This release retained all nine audit tests in the normal target and reproduced **8 passes / 1 failure** at `/private/tmp/hackers-invalid-gross-reproducer.xcresult`: stored zero/negative gross scores could improve totals and complete holes. Phone entry uses a minimum of one and Watch commands validate 1–20, but malformed/legacy stored data was still miscounted. A three-condition guard now excludes nonpositive raw gross strokes from score resolution and recorded-score completion. Explicit relative-to-par zero/negative entries, picked-up holes and signed handicap allocations retain their existing meanings. No stored scorecard is rewritten. The final focused regression run passed all nine audit tests, including the reproduced failure and explicit relative-to-par zero.

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

- PR #14–16 focused release run: **248 passed, 0 failed, 0 skipped**; `/private/tmp/hackers-release-focused-final.xcresult`. Includes all nine blocker regressions, all eleven hosted keyboard checks and the live course-provider diagnostic.
- PR #14–16 full suite: **983 passed, 0 failed, 5 skipped** (988 total); `/private/tmp/hackers-release-full-fixed.xcresult`.
- Earlier focused fix run: **219 passed, 0 failed, 0 skipped**; `/private/tmp/hackers-release-blockers-fixed-1.xcresult`.
- PR #14–17 initial focused run: **277 passed, 0 failed, 0 skipped**; `/private/tmp/hackers-release-pr17-focused.xcresult`. Includes all nine Settings and 21 companion-contract tests.
- Final PR #14–17 focused run after invalid-score hardening: **286 passed, 0 failed, 0 skipped**; `/private/tmp/hackers-release-pr17-final-focused.xcresult`.
- Final PR #14–17 **full suite: 1,001 passed, 0 failed, 5 existing opt-in skips** (1,006 total); `/private/tmp/hackers-release-pr14-17-full.xcresult`. No tests were disabled or newly skipped.
- Final PR #14–17 **clean simulator build passed** after clean; app installed and launched to sign-in. Log: `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_run_sim_2026-10-16T10-57-52-502Z_pid36428_9a061311.log`. Screenshot: `/var/folders/lv/l852tplx755dks4wvkz1f5mr0000gn/T/screenshot_optimized_a7c85fe8-c977-4e4b-b1a1-c7ff0897ad8d.jpg`.
- The existing PR workflow now includes `InternalReleaseBlockerAuditTests`, `ScoringRobustnessTests` and `GolfCourseRepositoryTests`, in addition to PR #17’s Settings and companion contracts. The complete local suite above is the release evidence. GitHub Actions for app-code commit `9459c717` also completed successfully: Score Carousel Tests, run 58 (`38890454646`).
- `git diff --check` passes.
- PR #14–16 clean simulator build **passed** after clean; installed and launched to sign-in. Log: `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_run_sim_2026-10-16T10-43-31-034Z_pid36428_7187329f.log`. Screenshot: `/var/folders/lv/l852tplx755dks4wvkz1f5mr0000gn/T/screenshot_optimized_7a2ff3a3-b005-405d-8dae-acb02e09094c.jpg`.

The standard five skipped cases are existing opt-in OCR/chat/live-course diagnostics or previews, not passed tests. The live provider diagnostic was separately enabled and passed: search returned two Verdae matches and current opaque ID `xnmmcgzp` loaded eight tees, including an 18-hole scorecard. This verifies the course service, not signed-in Firebase writes.

Simulator: iPhone 17 Pro, iOS 26.3.1, Sandbox configuration. The full suite exercises positive and signed allocation, caps, 9/18-hole course setup, personal calculation/history, registered/reusable guest prefill, league/team scoring and snapshots. The three local resume integrations verify nine/front/back/eighteen-hole navigation, previously entered scores, durable current-hole restoration through a new AppSession, and repeated listener hydration without default-score overwrites.

All 11 hosted keyboard regressions cover HandicapEntryView, ManagePlayerView and the actual roster input/dismiss control in both Handicap Index and Strokes Received modes. Done is visible and accessible with a 44-point target, closes actual UIKit numeric-keyboard focus, preserves the value, and does not trigger a save, navigation or clear. The roster's existing edit-driven debounce remains separate from dismissal. Ticket **wdx6zf0n03 is complete in PR #16** within this tested setup scope.

Gross/net score projections, scorecard and leaderboard have automated coverage. No dedicated manual Wolf round was played; its rules were not modified. The personal expected-nine conversion remains the existing unofficial Hackers approximation, not USGA/GHIN certification.

Existing compiler warnings remain, including recursive helper branches in `ModifierApplicator` for the unused `allPlayersMatch` predicate and the unused coordinate `distance(to:)` extension. Repository search found no shipped template or UI construction of that predicate and no callers of the coordinate extension; active course distance paths use CLLocation. They were not changed as part of this release. Custom/remote pipelines using that unsupported predicate are not covered by this internal acceptance. Existing Swift 6 migration warnings also remain; this candidate builds in the established Swift language mode.

## Smoke-test limits

The clean simulator app launches to sign-in. No signed-in Firebase app session was available, so authenticated Firebase round creation/write/reload, real concurrent-device scoring and a signed-in end-to-end course/tee/round smoke test were not performed. `xcrun devicectl list devices` returned **No devices found**; physical-device scoring, OS lock/unlock and real suspension acceptance remain outstanding. The durable resume/hydration tests are local integrations and do not claim those device checks passed. These limits are disclosed for internal testing; there are no remaining known critical scoring/history failures in the executed release checks.

## Signing and internal distribution

| App | Version / build | Apple state | Internal availability |
| --- | --- | --- | --- |
| Hackers Compete | 1.0.0 / 2026.10.16.1 | VALID / INTERNAL_ONLY / IN_BETA_TESTING | Beta group contains the build; external group does not. |
| Hackers Compete Test | 1.0.0 / 2026.10.16.1 | VALID / INTERNAL_ONLY / IN_BETA_TESTING | Beta group contains the build; external group does not. |

Apple API evidence, exact build IDs and group checks are preserved in [apple-build-status.json](apple-build-status.json). Both variants are available for internal installation, not App Store/external distribution. Source app code is identical at `9459c717`; packaging/configuration differs as recorded below.

Sandbox build: **1.0.0 (2026.10.16.1)**. Prior latest Apple build was 2026.10.15.1. The PR #14–16 archive was stopped when PR #17 was added to scope. The fresh PR #14–17 signed archive, internal-only export and upload succeeded. Apple build ID `1b037977-6313-4da7-997a-d53163e71772` is `VALID`, audience `INTERNAL_ONLY`, internal state `IN_BETA_TESTING`, external state `NOT_APPLICABLE`. At 07:14 EDT its internal Beta build list contains this exact build. A 07:27 EDT verification also confirms the external Beta Testers group does not contain it. It is available for internal installation; no external assignment is possible for this binary. Internal group **Beta** has access to all builds; no external distribution is requested.

The Sandbox app is **Hackers Compete Test**, bundle `com.tigermindlabs.hackers.compete.sandbox`, App Store Connect ID `6757443901`, team `28EF5GR4R6`. The established workflow overrides `CURRENT_PROJECT_VERSION` for the app and companion targets. The archive and IPA confirm **1.0.0 (2026.10.16.1)** on the iPhone app and embedded Live Activity extension. The existing Sandbox project configuration explicitly excludes the Watch app (`EXCLUDED_EXPLICIT_TARGET_DEPENDENCIES` / `EXCLUDED_SOURCE_FILE_NAMES`); no Watch app is bundled. PR #17’s Settings UI and companion gating are included, but this Sandbox package cannot provide a Watch playthrough. No packaging/signing configuration was changed to expand scope. The Fastlane lane enables external testing by default and was not used. Export/upload uses Xcode `app-store-connect`, automatic signing, `manageAppVersionAndBuildNumber=false`, and **`testFlightInternalTestingOnly=true`**. No external group assignment, beta/App Store review submission or main merge is authorized or performed.

Archive: `/private/tmp/HackersInternal20261016-PR17.xcarchive` (archive log `/private/tmp/HackersInternal20261016-PR17-archive.log`). Exported IPA: `/private/tmp/HackersInternal20261016-PR17-account-export/Hackers.ipa` (65,959,251 bytes; SHA-256 `ec4966640d14b78d282495aadd0f166f32276eb0a56fa5c0bd54948287c6e379`). `codesign --verify --deep --strict` passed with access to macOS trust services. The distribution identity is Apple Distribution: Tiger Mind Labs LLC, team `28EF5GR4R6`; `beta-reports-active=true`, `get-task-allow=false`. The actual exported options retain `testFlightInternalTestingOnly=true`.

The API-key export attempt failed because that key lacks cloud-signing access and there is no local Distribution identity. The existing signed-in Xcode account then exported successfully, without new credentials or permission changes; the same account uploaded successfully at 07:08 EDT. Export log: `/private/tmp/HackersInternal20261016-PR17-account-export.log`; upload log: `/private/tmp/HackersInternal20261016-PR17-account-upload.log`.

The upload succeeded with missing-dSYM warnings for the main app, Live Activity extension and several vendored frameworks. This limits symbolicated crash diagnostics; it did not fail package upload or Apple processing. No claim of complete symbols is made.

**Install-and-play: Hackers Compete Test is available now to internal Beta testers.** Physical-device/authenticated smoke limits above still apply.

### Main Hackers Compete app

The user explicitly requested uploading the same code to **Hackers Compete** as well, still internal TestFlight only. App Store Connect ID `6757131203`, bundle `com.tigermindlabs.hackers.compete`, existing Production scheme/configuration and team `28EF5GR4R6`. Its previous latest build is 2026.10.14.1, and the new build is **1.0.0 (2026.10.16.1)**. Internal group **Beta** (`5b4877fb-cd30-42c9-9c55-d2b27bc9d2ca`) has access to all builds. The existing external group is untouched; the new upload enforces `testFlightInternalTestingOnly=true`. The Production archive/IPA includes its Watch companion; all companion versions and signatures were verified. No backend services or rules are deployed by this app upload.

The Production signed archive and internal-only export **passed**. Its iPhone app, Watch app (`com.tigermindlabs.hackers.compete.watchkitapp`, companion ID matches the phone), and Live Activity extension all report **1.0.0 (2026.10.16.1)**. All three app dSYMs are present in the archive. The exported IPA passed `codesign --verify --deep --strict`; actual export options confirm `testFlightInternalTestingOnly=true`. IPA: `/private/tmp/HackersInternalProduction20261016-export/Hackers.ipa`, 63,200,476 bytes, SHA-256 `dad07f90c33ad3ad618d08306209f60b8351a707dbd510bdb7d2bc8b490b315e`.

**Production simulator limit and resolution:** the initial clean build compiled the app but failed `ValidateEmbeddedBinary` because the default mixed-platform target selection embedded a device Watch binary in the iOS Simulator bundle. The tool had reached its 300-second wait limit while its compiler continued; the final underlying failure was recorded and not treated as a pass. An explicit iOS Simulator SDK retry instead compiled Watch sources against iOS and failed to import WatchKit. The final **phone-only Production simulator build/install/launch passed** using command-only Watch exclusions copied from the existing Sandbox configuration: `EXCLUDED_EXPLICIT_TARGET_DEPENDENCIES=Hackers\ Watch\ App` and `EXCLUDED_SOURCE_FILE_NAMES=Hackers\ Watch\ App.app`. Only the stale generated Simulator Watch copy was removed. No source or project file changed for this workaround; all automated tests remained enabled, no optimization settings were weakened, and the complete signed device archive/IPA retains Watch. Watch simulator/physical behavior is unverified. Final phone simulator log: `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_run_sim_2026-10-16T11-37-04-049Z_pid36428_d95de4b3.log`; it launched to sign-in, screenshot `/var/folders/lv/l852tplx755dks4wvkz1f5mr0000gn/T/screenshot_optimized_644dc6c7-d9e8-4900-b428-7a2283395bf9.jpg`. This additional build uses the same tested scoring/history code; those files contain no Sandbox/Production compilation branches. Archive path: `/private/tmp/HackersInternalProduction20261016.xcarchive`. Production upload **succeeded at 07:44 EDT**. Apple processing is complete: build ID `01708b51-3cee-40a7-a26e-e78e88b6fff4`, `VALID`, audience `INTERNAL_ONLY`, internal `IN_BETA_TESTING`, external `NOT_APPLICABLE`. Its internal Beta group contains this exact build and its external Beta Testers group does not. **Hackers Compete is available for internal installation now.** Upload log: `/private/tmp/HackersInternalProduction20261016-upload.log`. Missing-dSYM upload warnings remain for ten vendored frameworks; main iPhone, Watch and Live Activity dSYMs were included. These warnings did not prevent upload or processing.

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
