# Series handicap local audit — 2026-10-18

## Source and scope

Candidate: `/private/tmp/HackersPR16IndexEntry`, detached HEAD
`2665d1a04ddb2b8a132f121a1578fc6ac3d71094` (2026-10-18).
Application changes and regression tests remain uncommitted. No push, merge,
Firebase deployment, or TestFlight upload was performed.

The separate `/Users/Kirsten/Developer/Hackers-Combined` checkout contains
pre-existing user changes and was preserved. It is older than this candidate.

## Comparison with the code before PRs 14–17

Read-only Git comparison used pre-PR main `731f5619` (merge of PR 13) and the
candidate's committed source, rather than comparing against our local fixes.

* `SeriesView.swift`: the start path and settings presentation are unchanged.
  A saved course goes directly to creation, bypassing an opportunity to review
  missing player handicaps. The failure alert offers only OK. Handicap settings
  are inside the commissioner gear menu.
* `SeriesHandicapSettingsView.swift`: unchanged. Save starts an asynchronous
  operation and dismisses immediately. The corresponding view-model method
  updates local state optimistically and discards the Firebase write result.
* `SeriesMemberEditorSheet.swift` and `SeriesHandicapOverrideView.swift`:
  unchanged. A permanent commissioner override already exists. The member
  editor hides handicap entry while series handicaps are Off. This is separate
  from a personal profile Index or a round-only stroke allowance.
* `SeriesRosterView.swift`: the existing handicap chip is conditional on series
  handicaps being enabled. It opens the breakdown. This condition predates the
  latest PRs.
* `SeriesViewModel.isCommissioner`: unchanged. The owning commissioner's user ID
  works directly; other roster commissioners require the primary player ID.
  A linked commissioner whose player ID has not loaded can lose controls.
* The missing-Index preflight and the dead-end alert were introduced together
  by `d67a09dd` (2026-08-05), before these PRs. Its parent allowed creation
  without that preflight. Participant mapping used `effectiveStrokes ?? 0`,
  and an absent Index could therefore become zero. This is a concrete way an
  earlier version could start successfully without complete handicap data.
* PR 14's `864af32c` changes the calculator integration and takes Index basis
  from series configuration. It retains an existing series preflight; it does
  not remove a handicap editor or settings control. Reverting it wholesale
  would discard unrelated calculation corrections.

These findings establish source history, not the exact configuration, saved
data, permissions, or binary used in the tester's earlier successful round.
There is no evidence from this comparison that PRs 14–17 removed the series
handicap controls. Restoring the old missing-to-zero fallback would violate
the explicit requirement to leave missing handicaps unresolved.

## Local fixes already implemented

* All series start paths lead through player handicap review, including a
  saved course. Registered and offline players can use a round-only 18-hole
  personal Index or manual strokes with selected tees and calculated previews.
* Personal/manual round scoring works independently of series handicap mode.
  Existing series calculations and permanent overrides remain separate.
* Valid entries persist on the planned series round; unfinished raw drafts
  persist locally by user, series, and round. Invalid or failed entry remains
  available for correction. No personal profiles are written.
* Planned-round writes use a transaction and reject stale or already-linked
  rounds. Live round-only handicap snapshots and their tees remain frozen.
* Settings are accessible from the roster and review. Save waits for success,
  exposes failure without dismissing, and retains the selection for retry.
* Existing roster commissioner authorization also recognizes the member's
  linked user ID while the primary player ID is unavailable.
* Missing allowances remain unresolved. Mixed legacy stroke bases and new
  round-only inputs are normalized with the existing allocation calculation.
  Wolf/scoring engine rules are not changed.

## Earlier evidence (superseded by resumed validation below)

* Clean committed candidate Sandbox simulator build and launch succeeded.
* The unsigned simulator install produced Google keychain auth error -2;
  a focused keychain probe returned -34018. Normal simulator ad-hoc signing
  resolved that probe. A subsequent launch restored an authenticated live
  round. Its hole and scores were not edited.
* Baseline audit: 9 passed, 4 failed, 0 skipped. Failures included missing
  strokes being treated as zero, linked commissioner recognition, unsigned
  keychain access, and a hosted UI harness with an empty accessibility tree.
* Most recent focused run:
  `/private/tmp/hackers-series-fixed-focused-2.xcresult` — 234 passed,
  6 failed, 0 skipped. Two failures identified an obsolete missing-to-zero
  expectation and overly broad tee preservation in our sync change; both
  were corrected locally afterward. Four failures came from the new hosted
  UI tests finding an empty accessibility tree. The hosting helper was
  adjusted afterward, but that adjustment is not yet verified.
* Later changes, including draft persistence, those corrections, and the UI
  helper adjustment, have not received a final build or test run. Earlier
  passing results must not be presented as validation of the final diff.

## Resumed validation

The user subsequently authorized unfinished tests and other work. The previously
blocked direct Xcode test command was approved and executed. The final application
source is unchanged during this validation continuation.

* Final-source audit plus an existing keypad control test: 26 passed, 5 failed,
  0 skipped (`/private/tmp/hackers-series-ui-xcode.xcresult`). The five failures
  were UI accessibility lookup failures, including the previously existing keypad
  test. A captured screenshot proved that the settings screen had rendered its
  Off, Fixed, Dynamic, and Save buttons.
* The simulator runtime accessibility inspector was attached to the test-host
  app. The same four series UI tests and existing keypad control test then all
  passed: 5 passed, 0 failed, 0 skipped
  (`/private/tmp/hackers-series-ui-accessibility.xcresult`). This is a test
  environment requirement, not a product fix. Keep accessibility inspection
  active when running these in-process SwiftUI accessibility tests; empty
  accessibility trees without it must not be mistaken for missing app controls.
* Full Sandbox suite, same source and dedicated iPhone 17 Pro simulator:
  **1,062 passed, 0 failed, 5 skipped**, 1,067 total tests.
  Result bundle: `/private/tmp/hackers-series-full-final.xcresult`.
  Machine-readable summary: `/private/tmp/hackers-series-full-final-summary.json`.
  The runtime inspector was active during this run. All 30 new series audit
  tests and the existing mapping, sync, handicap history, scoring, keypad, and
  round resume tests passed. The full suite used the existing Sandbox scheme's
  Address Sanitizer configuration.
* Existing opt-in skips were left unchanged: two live scorecard OCR diagnostics
  (`RUN_LIVE_SCORECARD_OCR`), live course search/detail and live chat search
  (`RUN_LIVE_GOLFCOURSE_API_TEST`), and a course chat rendering diagnostic
  (`RENDER_COURSE_CHAT`). No tests were removed, newly skipped, or disabled.
* `git diff --check` passed.
* Fresh simulator build in `/private/tmp/HackersSeriesFinalCleanDerived`:
  **succeeded in 137.9 seconds**, with 0 compiler errors. This used Sandbox,
  arm64, and normal simulator ad-hoc signing, without changing project signing
  settings. Build log:
  `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_sim_2026-10-19T00-43-56-643Z_pid36428_6ea82986.log`.
* Installed that fresh app and launched it successfully on the dedicated test
  simulator. Runtime UI inspection confirmed the welcome/sign-in screen. This
  simulator has no authenticated session; that launch is not a live-series
  end-to-end test.
* The build retains existing compiler warnings, including recursion diagnostics
  in `ScoringEngine+Stages.swift:277` (`allPlayersMatch`) and `Location.swift:14`
  (the coordinate distance extension). Both files are unchanged from pre-PR main
  `731f5619`; no production construction of `allPlayersMatch` or calls to the
  coordinate extension were found in this source. They were not altered in this
  series-setup patch and remain separate latent issues, not passing runtime
  checks. The complete diagnostics remain in the build log.

Passing UI evidence:

* [Commissioner roster settings button](series-handicap-local-audit-2026-10-18/roster-settings.png)
* [Fixed settings saved and reopened](series-handicap-local-audit-2026-10-18/settings-fixed-reopened.png)
* [Round-only Index entry and calculated Course HCP](series-handicap-local-audit-2026-10-18/round-review.png)

## Remaining validation and restrictions

`xcrun devicectl list devices` reported **No devices found**. Physical-device
smoke testing therefore remains outstanding. No authenticated end-to-end
seven-player series reproduction or concurrent Firebase transaction test has
been completed; those paths used realistic in-memory fixtures and the actual
SwiftUI screens with injected persistence. Firebase metadata access earlier
reported expired CLI credentials. The earlier authenticated live-round restore
is not evidence that authenticated series workflows passed.

The original simulator containing the user's live round was not used or edited
during resumed testing. All application changes remain local and uncommitted.
No push, merge, backend deployment, or TestFlight upload was performed.

## Follow-up: actual Andrew’s golf trip round-setup badge

The user identified the simulator and Andrew’s golf trip as the remaining
problem. Inspection of that authenticated trip confirmed the account was shown
as Commissioner. In Edit Round, the `SERIES HANDICAPS / OFF` chip was plain text
inside `SeriesRoundHandicapParticipationCard`, not a selection control or link.
The prior UI tests covered the separate settings and roster routes and missed
this round-editor route.

Changed only that shared card in `NewSeriesRoundSheet.swift` to make its header
a commissioner-only, 44-point settings button with a chevron. It opens the
existing `SeriesHandicapSettingsView`; the same card serves New Round and Edit
Round. Non-commissioners retain the read-only status. It does not automatically
enable a mode, save a round, change participation, or alter calculations.

Added regression tests for New Round and Edit Round opening the settings,
saving Fixed with injected persistence, updating the badge, and preserving the
round draft; a separate test verifies the non-commissioner read-only behavior.
Those tests and the existing series handicap accrual tests passed in
`/private/tmp/hackers-series-badge-fix.xcresult`.

Rebuilt the Sandbox app successfully in 43.7 seconds and installed it over the
existing app on `Hackers iPhone 17 Pro` (no uninstall or data erase). Reopened
Andrew’s golf trip, opened Edit Round, scrolled to the badge, and verified with
normal coordinate taps that it opens settings and both Fixed and Dynamic
respond. Returned the draft selection to Off and left settings open without
pressing Save. No handicap setting, score, tee, or round draft was saved.

[Fixed selected in Andrew’s actual trip (unsaved draft)](series-handicap-local-audit-2026-10-18/andrews-trip-fixed-draft.jpg)

The post-fix full suite passed: **1,064 passed, 0 failed, 5 unchanged opt-in
skips**, 1,069 total tests, in `/private/tmp/hackers-series-badge-full.xcresult`.
The summary is `/private/tmp/hackers-series-badge-full-summary.json`. This supersedes the earlier full run for the current
application source. No commits, pushes, uploads, or backend deployments occurred.


## Follow-up: maximum Index and player Index visibility

The series maximum is an Index ceiling before tee conversion, not a ceiling on
resulting Course Handicap strokes. The previous post-conversion clamp was a bug.
The resolver now limits the calculation Index before 9/18-hole basis conversion
and tee adjustment, preserves the original Index and records the applied maximum.
Course Handicap and allocated strokes can exceed the maximum Index. Explicit
round-only strokes bypass this Index ceiling; generic explicit stroke-cap APIs
and legacy strokes-mode behavior remain unchanged. Calculator version is 3.

Live synchronization preserves existing frozen handicap snapshots and allowances.
Lobby inline and Manage Player editing also avoid reapplying an Index maximum as
a strokes cap; saving an unchanged allowance does not create an override.
Completed scorecards, profiles, and permanent series overrides are not rewritten.

The Round Handicaps sheet now shows Handicap Index above Course HCP and Strokes
Received. When the maximum limits the Index used, a note explains that. Manual
strokes show a separately available Index or Not set. Legacy integer stroke
allowances are never displayed as an Index.

Verified on the authenticated Sandbox simulator in Andrew’s golf trip using
Tobacco Road, Ripper, Full 18 (72.5/145/par71): Greg's Index17 gives Course HCP23
and Strokes Received23. Kirsten's Index30 remains visible, with the maximum21
note and Course HCP28/Strokes Received28. Normalization was Off. No actual trip
settings, overrides, scores, tee choices, or round creation were saved.

[Greg: Index, Course HCP and strokes](series-handicap-local-audit-2026-10-18/andrews-index-course-strokes.jpg)
[Kirsten: maximum Index note](series-handicap-local-audit-2026-10-18/andrews-index-maximum.jpg)

Validation:
- Focused handicap regressions passed, including 17-to-23 allocation/net scoring,
  Index cap before nine-hole conversion, plus Indexes, manual strokes, Codable
  provenance, frozen allowances, and commissioner overrides.
- Full suite: 1,072 passed, zero failed, five unchanged opt-in skips (1,077 total)
  in /private/tmp/hackers-series-index-and-display-full.xcresult.
- The final display-only correction and added legacy-strokes UI reproducer were
  validated afterward: both display UI tests passed in
  /private/tmp/hackers-index-display-final-ui.xcresult. The full suite preceded
  that last display-only correction; it was not repeated unnecessarily.
- Sandbox simulator build succeeded (69.2 seconds), followed by a successful
  27.2-second incremental build including the final display correction. Installed
  over the authenticated simulator app and verified the actual rows above.
- git diff --check passed.

Authenticated trip reads and unsaved review UI have now been verified, superseding
older statements that the original simulator was not used. Authenticated round
creation/concurrent Firebase writes and physical-device testing remain outstanding.
No commit, push, merge, backend deployment, or TestFlight upload occurred.
