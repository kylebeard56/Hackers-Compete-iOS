# Streamlined Series Round Handicaps

Follow-up to PR #16, based on `897278c0` (October 18 candidate). Development branch: `codex/wdx6zf3848-handicap-entry`.

## Root cause and preflight audit

`SeriesView.startRound` sends both start paths through `CourseSelectionForSeriesRoundSheet`. That sheet unconditionally sets `reviewCourse` from either the remembered/saved course or `onSetSeriesRoundCourse`. Neither path consulted handicap readiness before presenting the sheet. `SeriesRoundHandicapReviewView` then displayed the literal heading “Review Missing Handicaps” and an expanded editor for every participant. This was presentation behavior, not evidence that preflight had rejected those players.

The old row preview also reported missing handicaps for gross, stroke-entry rounds even when the authoritative `SeriesRoundHandicapSetup.issues` correctly allowed absent optional handicaps. It could show an unrelated personal Index next to a manual stroke entry. The new readiness projection follows the same requirement policy as the writer and displays Indexes only for Index-based inputs.

Explicit zero Indexes and zero manual strokes were already supported by the calculation/input code; they remain complete. Missing rating, nonfinite/zero rating, nonpositive slope, missing tee, missing playable-hole par, and unknown Index basis still block the relevant conversions. Nine-hole estimates still require exact segment data under the existing Series policy; this follow-up does not relax that policy. Manual strokes need a selected playable tee, but do not require rating/slope because no Index conversion is performed.

The audit additionally found two validation gaps, addressed here: gross rounds with optional handicaps previously skipped course validation entirely, and nonfinite legacy stroke inputs could yield nil strokes without a validation issue. Course validation now runs even when a handicap is optional; no missing handicap is invented as zero.

## Behavior

- All-ready rounds show “Ready to Start”, course/hole count, player count, compact rows, optional global/per-player Edit actions, and one primary Start Round button.
- Incomplete rounds show “Handicap Setup Needed”, the affected-player count, and editors expanded only for affected participants. Valid edits update the projection immediately; the active editor stays open while typing.
- Rows show one primary stroke value, original Index when relevant, tee and source. Applied Index maximums remain visible. Field-normalized strokes reuse the existing scoring eligibility/normalization functions and explicitly explain the difference from Course Handicap. Matchup normalization is described once in Round Scoring, since allocations vary by matchup.
- Rating, slope, par and calculation Index are behind Handicap Details. Round-only Index/manual editing, tee selection and recalculation retain the existing draft/input machinery.
- Use net scoring remains a competition-basis control in Round Scoring. An untouched inherited basis stays nil; an existing explicit basis is preserved. Temporary scoring changes survive reopening on the same series view model and are cleared after successful persistence. Gross/net score-entry and scorecard display code is unchanged.
- The start action applies the drafts, revalidates before persistence, then uses the creation service's independent authoritative preflight. Existing Firestore setup transactions and frozen snapshots remain in place. Local save/start guards additionally reject an in-progress creation and stale setup timestamps.

## Modified files

- `Hackers/Features/Series/Sheets/CourseSelectionForSeriesRoundSheet.swift`: compact confirmation, selective inline editors, details disclosure, concise scoring section, fixed primary action; injectable course-selection model for hosted path tests.
- `Hackers/Features/Series/Services/SeriesRoundCreationMapping.swift`: presentation-independent readiness projection, shared resolver/scoring reuse, course validation for optional-handicap rounds, finite stroke-input guard.
- `Hackers/Features/Series/ViewModels/SeriesViewModel.swift`: roster/attendance-aware readiness adapter, temporary basis draft, stale/in-progress guards.
- `HackersUnitTests/SeriesRoundStartAuditTests.swift`: 15 new regression methods, existing review assertions updated for compact presentation, isolated draft stores, inset-aware hosted scrolling.
- This report and selected hosted screenshots.

`SeriesRoundCreationService.swift` was reviewed. Its existing authoritative `SeriesRoundHandicapSetup.issues` call remains the final writer gate and picks up the shared validation improvement without duplicating calculation logic.

## Validation

**510 tests passed, zero failures, zero skips**, confirmed with `xcresulttool get test-results summary`, on iPhone 17 Pro / iOS 26.3.1, Sandbox, using local simulator ad-hoc signing. Result: `/private/tmp/StreamlineHandicaps-verified.xcresult`.

After final spacing/header presentation adjustments, all **49 hosted round-start tests passed again**, zero failures/skips. Result: `/private/tmp/StreamlineHandicaps-mobile.xcresult`. The reproducible expanded selected-suite command is in `/private/tmp/validate-streamlined-handicaps.sh`; use a new result-bundle path when rerunning. `git diff --check` passes. The PR development worktree's four changed source/test files were compared byte-for-byte with the tested candidate.

New coverage exercises: compact all-ready confirmation without mandatory editors; only the missing offline player expanded; real inline text editing/readiness; mixed registered/offline players, personal Index/manual zero, front/back nine and 18 holes in Off/Fixed/Dynamic modes; invalid tee/rating/slope; invalid local text without falling back to a saved allowance; selected tee validation retained with invalid text; original Index/maximum display; actual field-normalized strokes; optional gross versus required net inputs; saved overrides/reopening; substitutions and declined attendance; unchanged custom inputs/course/inherited scoring on save; stale setup and frozen live/completed rounds; duplicate/in-progress start rejection. Hosted integration tests exercise both the remembered saved-course route and the actual newly-selected-course callback into the shared confirmation.

Existing calculation, personal handicap/profile/history, Series history/accrual, round mapping/Codable/sync, commissioner override/access, activation, keyboard and scoring tests are included. No tests were disabled or newly skipped. Earlier failed attempts exposed a cleaned dependency cache, unsigned-simulator keychain access, and hosted assertions/scroll offsets needing updates for the new layout; these were corrected rather than bypassed.

Hosted screenshots: [Ready confirmation](streamlined-series-round-handicaps/ready.png), [Setup needed](streamlined-series-round-handicaps/setup-needed.png), [Saved-course route](streamlined-series-round-handicaps/saved-course.png), [New-course route](streamlined-series-round-handicaps/new-course.png). These use synthetic local fixtures and exercise production views without creating server rounds.

## Remaining device/server acceptance

- Authenticated Firestore save/reload and round creation for saved and freshly fetched courses, including offline recovery and listener updates.
- Concurrent starts from two devices; local duplicate/stale guards and the existing setup transaction are covered, but server concurrency was not exercised.
- Small iPhones, larger Dynamic Type, dark mode, keyboard/tee-picker interaction and long player names on physical devices.
- Confirm net remains alongside gross in actual score entry/scorecards and that matchup-relative allocation follows existing lobby/scoring behavior.

No merge, deployment, TestFlight upload, permanent player-profile edit, team-selection change or scorecard-dot change was performed.
