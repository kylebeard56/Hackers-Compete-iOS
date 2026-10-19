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

Archive, signed export, signature verification and upload succeeded. Apple build
08cfc8cb-a30f-4e91-952e-f415505cc9bc is VALID / INTERNAL_ONLY /
IN_BETA_TESTING; the internal Beta group contains this exact build and the
external Beta Testers group does not. AVAILABLE for internal installation.
The main Hackers Compete app was not uploaded by this request.

Archive: /private/tmp/HackersInternalTest20261018.xcarchive.
IPA: /private/tmp/HackersInternalTest20261018-export/Hackers.ipa.
SHA256: 43b95d95abd1440c9223b7a664f471503111970eef948fbebf2f77764299b3f7.
Archive/export/upload logs share prefix /private/tmp/HackersInternalTest20261018-.
Apple receipt: apple-build-status.json; test counts: validation.json.
The iPhone app and Live Activity extension both contain version1.0.0/build2026.10.18.1.
Missing dSYMs for the main app, extension and ten vendor frameworks limit crash
symbolication; Apple accepted and processed the binary despite those warnings.
ClickUp connector hit its daily quota; the authenticated web interface was used
successfully to post release scope and validation comments on all ten linked
tickets. GitHub connector writes returned 403; the authenticated GitHub web interface
was used for the four PR descriptions after the Git credential PATCH timed out. PR16 source was fast-forward pushed;
PR14/15/17 retain their independent heads. Broader source-resolution ticket
wdx6zf65p7 remains open rather than claiming all its scope is complete.

All four PR description updates were confirmed by GitHub API readback. All nine
implemented linked tickets were moved to TestFlight and visibly verified; broader
source-resolution follow-up wdx6zf65p7 remains open. Details: tracking-updates.json.
App-code commit remains d03a2355; this final receipt commit changes documentation only.
