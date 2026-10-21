# Complete TestFlight candidate — October 21, 2026

Version **1.0.0**, build **2026.10.21.1**. Source branch: `codex/testflight-complete-2026-10-21`, validated source commit `43dabbec57e272cf6e6c551d008c53e09eb9d7eb`. Application source is identical to `84b9ad2a`; the later commit reconciles retained local test fixtures only.

## Included work

Latest fetched `main` (`731f5619`) and the complete current histories of open PRs **#14, #15, #16 and #17** are ancestors of this release branch. This includes the Player Insights/scorecard changes on main, all personal/Course Handicap and series work, mixed-entry/frozen-basis corrections, and account-aware companion restoration. Exact PR heads are recorded in `manifest.json`.

All local application changes, regression tests and documentation from the original `/Users/Kirsten/Developer/Hackers-Combined` checkout are incorporated or retained through their newer upstream implementation. The scorecard renderers and extra course, resume and concurrency regressions are committed. The already-integrated scoring robustness suite is retained once to avoid a duplicate class. Course failure fixtures were updated for typed course IDs, playable tee data, repository-owned asynchronous writes, session caching and explicit provider search. All eleven course cases remain enabled.

The original checkout was not switched or edited. `local-snapshot/working-files.tar.gz`, its patch and SHA-256 manifest preserve every original changed/untracked file, including Finder/Xcode user state and the old simulator ZIP. Those machine-local/generated files are preserved as evidence rather than embedded in the application. All original snapshot hashes were rechecked successfully.

## Validation

Full final suite: **1,128 passed, 0 failed, 5 existing opt-in skips**, confirmed by `xcresulttool`. Simulator: iPhone 17 Pro / iOS 26.3.1. No new skips or disabled tests. Signing was enabled for simulator tests so the keychain diagnostic passed. Result: `/private/tmp/HackersComplete20261021-final-validated.xcresult`; machine-readable summary: `validation.json`.

The initial GitHub-only unsigned baseline passed 1,088 cases and failed only keychain access. Enabling simulator signing resolved that environment failure. Retained local scorecard/resume/concurrency cases passed; all eleven reconciled course failure cases passed before the full final run.

Both archives use the same combined source and override `CURRENT_PROJECT_VERSION=2026.10.21.1` and `DEBUG_INFORMATION_FORMAT=dwarf-with-dsym`. Production includes Watch and Live Activities; Sandbox retains its existing Watch exclusion. Archive receipt and smoke results are recorded in `manifest.json`.

Physical-device/paired Watch/Lock Screen and authenticated Firebase multi-device acceptance have not been performed during this preparation.

## TestFlight handoff

Archives and release files are saved in:

`/Users/Kirsten/Developer/Hackers-Combined/build-artifacts/complete-2026-10-21`

- `Hackers-Sandbox.xcarchive` — Hackers Compete Test, `com.tigermindlabs.hackers.compete.sandbox`
- `Hackers-Production.xcarchive` — Hackers Compete, `com.tigermindlabs.hackers.compete`
- `ExportOptions.plist` — internal TestFlight export, automatic signing, build-number preservation
- `WhatToTest.txt` — proposed tester notes
- `export-testflight.sh` — retry both IPA exports after signing is available

**IPA export is blocked by distribution credentials.** Xcode reports `No Accounts` and no local iOS Distribution signing identity. The existing repository API key was tried and reports a cloud-signing permission error. It has not been copied into the release files. Sign into an appropriate Apple developer account under **Xcode → Settings → Accounts**, then run:

```sh
bash /Users/Kirsten/Developer/Hackers-Combined/build-artifacts/complete-2026-10-21/export-testflight.sh
```

Alternatively, open the appropriate `.xcarchive` in Xcode Organizer and select Distribute App for TestFlight internal testing. Existing export options set `testFlightInternalTestingOnly=true` and `manageAppVersionAndBuildNumber=false`.

No IPA has been uploaded, no PR has been merged into main, and no backend was deployed. The final source branch is local and preserved in the attached managed worktree. Distribution authentication is the remaining step before export/upload; the archives should not be described as uploaded or available in TestFlight.
