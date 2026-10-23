# Fix startup crash paths and commissioner Index/tee editing

Production build 2026.10.22.1 aborted during Swift async-let cleanup shortly after launch. Replace the dashboard and personal-handicap startup pairs with structured task groups, retaining concurrent requests and independent error states. Dashboard cancellation drains its children and prevents publishing companion readiness. Upgrade Firebase from 11.15.0 to compatible 12.19.3 (Google Sign-In 9.2.0), which includes the upstream Auth/Functions cleanup workaround, and retain required Objective-C linkage.

Five crash reports share the same concurrency stack. The archived dSYM matches, but the app continuation is compiler-deduplicated, so the exact original source function is unproven. [Investigation and validation](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/codex/commissioner-index-tees/Documentation/startup-async-let-crash/README.md).

Commissioners can also save an Index with the keyboard open, edit it directly from Handicap Details, and select independent tees for each Series player:

- Keep Save override in the persistent footer, separate keyboard dismissal/cancellation, retain drafts on failure, validate commissioner permissions, and reject stale writes atomically.
- Persist each player's tee separately from Index/round-only inputs. Recalculate lobby Course HCP while preserving manual strokes and locking started/completed snapshots.
- Reuse the authorized Index editor for registered/offline members, including missing Indexes and zero-score histories.

Tickets: [Hidden Save](https://app.clickup.com/t/wdx6zf77zq), [Series per-player tees](https://app.clickup.com/t/wdx6zf77zr), [Override/tee independence](https://app.clickup.com/t/wdx6zf77zt), [Edit Index](https://app.clickup.com/t/wdx6zf6vm2).

This PR targets `codex/consolidated-rc-2026-10-21` (#18), which contains overlapping work from #14–#17. The normal-priority Fixed Handicap settings ticket remains excluded. Unrelated work in the original checkout is preserved.

## Validation

- Full available suite in optimized Production configuration: **1,186 passed, 0 failed, 5 existing opt-in skips**. Includes commissioner, round start/resume/readiness, scoring, handicap, Series, companion contracts, four new startup coordinator tests, and two new Firebase cleanup tests (20 network failures each).
- **12/12** signed-out cold launches on iPhone 17 Pro simulator / iOS 26.3.1 stayed alive at least 15 seconds and reached the sign-in screen. Optimized coordinator stress also passed 10,000 cycles and pre-cancellation; the old isolated pattern passed too, so this is stress evidence rather than exact crash reproduction.
- Production iPhone, Apple Watch, and Live Activity archive/export passed with Fastlane in **build-only** mode. All bundles are **1.0.0 (2026.10.22.2)**, signatures are valid, and all three dSYMs match, including both Watch architectures.
- Earlier commissioner validation: all 59 tests passed on iPhone SE with Address Sanitizer; the keyboard regression checks a nonzero software-keyboard frame and visible Save button. `git diff --check` passes.
- Five unchanged opt-in live API/OCR/preview diagnostics remain skipped. No existing tests were disabled. Initial new-fixture failures (invalid fake-key format and incorrect transport-error assertion) were corrected before the successful full run; details are recorded in the investigation documentation.

An affected physical iPhone is unavailable. Signed-in restoration and launch/round-start confirmation on iOS 26.6/26.6.2, authenticated Firebase acceptance, and physical iPhone/Watch synchronization remain manual checks. Simulator success does not prove resolution on the originally affected devices.

## Deployment held for review

**2026.10.22.2 has not been uploaded to TestFlight.** The user requested a PR update and will wait for review. Testing notes are prepared locally; no new testing notes or tester notifications were posted. The crashing **2026.10.22.1 remains expired**. Earlier Sandbox/Production release receipts in this PR are historical records.

The signed archive, exported IPA, dSYMs, complete successful Xcode result, and logs are preserved locally under `build-artifacts/production-startup-fix-2026-10-22`. [Validation receipt](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/codex/commissioner-index-tees/Documentation/startup-async-let-crash/validation.json) and [prepared testing notes](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/codex/commissioner-index-tees/Documentation/startup-async-let-crash/what-to-test.txt).
