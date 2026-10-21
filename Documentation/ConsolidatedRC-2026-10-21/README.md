# Consolidated release candidate — October 21, 2026

This candidate combines the complete current histories of PRs #14–#17 and main, the original checkout’s local Settings, scorecard renderer and regression work, and the PR #16 checkout’s compact round-start and typed course identity/tee validation fixes. Build identifier: **2026.10.21.2**.

The existing combined branch at `be248b51` supplied the complete PR histories, main’s Player Insights changes, newer companion restoration, and reconciled course/resume/concurrency tests. The missing round-start/course patches were applied only where the combined base still matched the PR #16 baseline. Existing scorecard changes were retained alongside main’s newer Insights code. No new scoring rules or handicap calculations were introduced during consolidation.

Original checkouts are unchanged. Their changed/untracked files, binary patches and SHA-256 manifests are backed up beside this source checkout. Finder state, Xcode user state and generated prior builds are retained as backups, not application source. The duplicate scoring robustness suite is represented once by the existing root test file.

## Validation

The full rerun passed: **1,175 passed, 0 failed, 5 existing opt-in skips** (1,059 XCTest + 116 Swift Testing). All 14 hosted keyboard tests also passed separately after initializing accessibility on the fresh simulator. The initial run was interrupted during disk exhaustion and had accessibility lookup failures; no app logic changed for the passing rerun. Optional simulator diagnostics were stopped after test completion to finalize the result; the modern summary is empty, so `validation.json` records the successful legacy action metrics and complete test log. The full suite uses a newly created simulator without existing Firebase credentials. No production app or signed-in Sandbox app is launched during this validation. Prior reports under `CompleteBuild-2026-10-21` and `verdae-series-course-validation` describe earlier source snapshots; they do not certify this consolidated build.

Physical-device, paired Watch, Lock Screen/Dynamic Island, and authenticated multi-device acceptance remain manual checks. The earlier live Sandbox report includes an initial preservation-check failure caused by normal account restoration; its isolated rerun passed. Consolidation does not repeat those authenticated writes.

The user subsequently authorized TestFlight upload. No push, merge or backend deployment is authorized or performed. The Sandbox archive succeeded and passed recursive code-signature, version and source-hash checks. CLI upload hit profile/certificate mismatches, API profile creation returned 403, and account-based CLI export failed. Xcode Organizer through the signed-in Admin account completed the internal-only Sandbox upload. Organizer marked build 2026.10.21.2 as Uploaded to Apple. App Store Connect confirmed build ID `61f460c3-8775-41f0-82d8-f6e47b06fc58` is **VALID** and **IN_BETA_TESTING**. Internal testers can install it now. The existing internal Beta group has access to all builds. Ten vendor framework dSYMs were unavailable; application and Live Activity dSYMs match their binaries. These warnings affect vendor symbolication, not upload acceptance. The user subsequently requested both TestFlight apps. The matching Production archive succeeded; all app/Watch/Live Activity signatures, symbols, version 2026.10.21.2, Production Firebase selection and original tested source hashes were verified. Organizer confirmed the Production upload succeeded for build 2026.10.21.2, using internal TestFlight only. Apple confirmed Production build ID `3b0c2f0e-cbdf-4f22-8a7c-fda1b43282f6` is **VALID / IN_BETA_TESTING**, with no delivery errors. Production has the same ten vendor-framework symbol warnings; app, Watch and Live Activity symbols were verified. The existing internal Beta group has access to all builds. Existing archives for build 2026.10.21.1 predate the compact/course fixes and must not be used for this candidate.

## Final TestFlight availability

Both apps are available to their existing internal Beta groups on build **2026.10.21.2**. The Test and Production binaries contain the same consolidated application source from PRs #14–#17 and both original checkouts, using their existing environment-specific configurations. Production also embeds the Watch app.

| App | App Store Connect ID | Build | State |
| --- | --- | --- | --- |
| Hackers Compete Test (Sandbox) | 6757443901 | 2026.10.21.2 | VALID / IN_BETA_TESTING |
| Hackers Compete (Production) | 6757131203 | 2026.10.21.2 | VALID / IN_BETA_TESTING |

Fresh API receipts are stored in `both-testflight-builds.json`, `apple-build-status.json`, and `apple-production-build-status.json`. No code was pushed or merged, no public App Store release was submitted, and no backend or production user records were modified.
