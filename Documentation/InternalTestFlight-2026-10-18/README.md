# Hackers Compete Test internal release — October 18, 2026

Target: Hackers Compete Test, bundle com.tigermindlabs.hackers.compete.sandbox,
App Store Connect 6757443901, version 1.0.0, build 2026.10.18.1.

Only open PRs #14, #15, #16 and #17 are included. PR14 140f22ce and PR15
e9782443 are ancestors of PR16 2665d1a0. PR17 be001f41 is included through
its existing two cherry-picks d1e90f34/e01763d9, retaining the personal profile
section during the original integration. No PR is merged into main.

This release adds the locally validated series setup fixes: actionable missing
Index review, personal 18-hole Index/manual round strokes for registered and
offline players, persisted setup drafts, commissioner settings access from roster
and round editor, safe settings-save errors, maximum series Index applied before
tee conversion, visible player Index/Course HCP/strokes, and protection of frozen
allowances. Existing single personal Index, history, scoring and companion fixes
remain included. See ../series-handicap-local-audit-2026-10-18.md for root causes,
file details, screenshots and test evidence.

Validation before release: full suite 1,072 passed, 0 failed, 5 existing opt-in
skips; the final display-only correction and new legacy-strokes UI regression
then passed both focused UI tests. Simulator build/install/launch succeeded.
Authenticated Andrew’s trip review shows Greg Index17 -> Course HCP23 -> strokes23;
Kirsten Index30 with maximum21 -> Course HCP28 -> strokes28. No trip settings or
scores were saved. Authenticated Firebase round-creation/concurrency and physical
device/paired Watch/Lock Screen acceptance remain unverified. Sandbox packaging
excludes Watch as before. Existing compiler/symbol warnings are not waived tests.

Distribution uses the existing signed-in Xcode account and automatic signing,
app-store-connect export, manageAppVersionAndBuildNumber=false and
 testFlightInternalTestingOnly=true. No production services, external TestFlight,
App Store publication or main merge is authorized.

Archive/upload/processing: pending; final receipt will be appended after verification.
ClickUp updates are currently blocked by the connector daily limit (100/100).
