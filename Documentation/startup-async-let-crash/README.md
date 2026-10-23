# Production startup crash fix

Five Xcode reports for Hackers Compete 1.0.0 (2026.10.22.1) show a main-thread SIGABRT about 3–10 seconds after launch on iOS 26.6/26.6.2. The common stack ends in `swift_Concurrency_fatalError`, `_swift_task_dealloc_specific`, and `asyncLet_finish_after_task_completion`. The archived dSYM UUID matches; the app continuation is compiler-deduplicated and does not identify an exact source line. [Investigation](investigation.md).

## Change

- Replace the dashboard's sibling `async let` requests with a structured task group. Both requests still run concurrently; the task group drains both children, and cancellation prevents publishing companion readiness.
- Remove the same `async let` pattern from the dashboard personal-handicap loader while preserving its independent error states.
- Resolve Firebase 12.19.3 and Google Sign-In 9.2.0, including Firebase's maintained Auth/Functions cleanup fix ([upstream PR #15991](https://github.com/firebase/firebase-ios-sdk/pull/15991)). The shipped Firebase 11.15.0 includes both problematic request-context patterns. The new SDK source uses cancellable tasks instead.
- Firebase 13.1.1 was checked, but its App Check 12 requirement conflicts with the released Google Sign-In 10 package's App Check 11 requirement. The compatible Firebase 12 release is used rather than changing either SDK's dependency manifest. The lock file preserves unrelated package versions.
- Retain `-ObjC` for app linking. The Swift Xcode project editor reorders some existing project entries; semantic comparison confirms unchanged project object identities, targets, schemes, phases, and source membership. Only the two package requirements and app linker flags change.

## Regression coverage

`DashboardStartupLoaderTests` covers concurrent startup, readiness only after both requests finish, cancellation while children are pending, already-cancelled startup, and repeated completion. `FirebaseStartupCrashRegressionTests` exercises Auth request-header and callable-context cleanup through public SDK APIs against a closed loopback endpoint using a separate Firebase app with fake project configuration. No production account or customer backend is used by these tests.

The actual coordinator was compiled with `swiftc -O` and completed 10,000 startup cycles plus a pre-cancelled load. The old pattern also passes in the isolated macOS harness, so that result is stress validation, not a reproduction of the affected iOS device crash.

## Validation

The complete Production suite passed with release optimization: **1,186 passed, 0 failed, 5 existing opt-in skips** (1,191 total). Both new Firebase tests passed 20 repeated network failures each. Twelve signed-out simulator cold launches remained alive for at least 15 seconds each and reached the sign-in screen. The Production device archive and exported IPA include iPhone, Apple Watch, and Live Activity, all version 1.0.0 (2026.10.22.2), with valid signatures and three matching dSYMs. See [validation.json](validation.json), [test summary](test-summary.json), and [archive verification](archive-verification.json). The available simulator runs iOS 26.3.1; no affected physical iPhone is connected, and the user confirmed they do not have one available. A physical-device run on iOS 26.6/26.6.2 remains necessary to confirm the reported crash no longer occurs. Do not describe simulator success as proof that this exact device crash was reproduced or fixed.

Initial SDK-test attempts failed in the new test fixture before testing request cleanup: Firebase Installations rejects API keys with an invalid format. An XCTest error-observation abort in that attempt was not a confirmed reproduction of the shipped async-let crash. The tests now use Swift Testing, a valid-format dummy key, and explicit network-failure assertions. A subsequent assertion correction accounts for Functions propagating URLSession connection-refused errors rather than wrapping them in the callable error domain. These failures and their logs are retained; no existing tests were disabled.

## Release status

PR review follow-up: the two lobby tee regressions are fixed. Gross players without a handicap snapshot can select a valid tee without creating an allowance; manual-strokes tee changes preserve the stored Index state and do not create an Index calculation. All **197 focused Production tests passed, 0 failed, 0 skipped**, including both new regressions across 18-hole/front-nine/back-nine layouts and persistence. See [review regression validation](../commissioner-index-tees/review-regression-fixes.json). The existing 2026.10.22.2 archive and the full-suite/cold-launch evidence above predate these follow-up fixes; no replacement archive or upload was performed.

Build **2026.10.22.2 was not uploaded**. The user requested holding deployment and updating PR #19 for review. Testing notes in what-to-test.txt are prepared locally and are not posted to App Store Connect. The crashing build 2026.10.22.1 remains expired. The signed archive, IPA, dSYMs, successful .xcresult, and logs are preserved under the original checkout’s build-artifacts/production-startup-fix-2026-10-22 directory.
