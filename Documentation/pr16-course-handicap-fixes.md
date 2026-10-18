# PR #16 Course Handicap acceptance fixes

Tickets: [offline temporary Index](https://app.clickup.com/t/wdx6zf6nxh), [18 → 9 navigation](https://app.clickup.com/t/wdx6zf6nxg), [manual strokes label](https://app.clickup.com/t/wdx6zf6nxf).

Continues PR #16 from `06de235a`, incorporating the supplied roster fixes with a setup-only preview safeguard. Upstream PRs and the existing release work are preserved.

## Reproduction and root causes

- **Offline Course Handicap unavailable: already corrected in the current candidate.** The supplied reproduction passes before applying this patch, including a guest with an empty tee ID using the round's default tee. The real ManagePlayerView also calculates Index 17.7 → Course HCP 8 for registered and offline fixtures. Both use the same HandicapCalculator and the existing single 18-hole personal Index policy. No additional offline-player calculation or profile write is introduced.
- **18 → 9 stale strokes: reproduced in the display.** The roster formatter preferred the stored resolution even when the currently selected course/segment differed. The baseline regression shows Course HCP 31 / strokes 21 instead of front-nine Course HCP 11 / strokes 11. Existing participant recalculation already handles the selected segment, but the saved participant update is asynchronous. The lobby must preview the current selection while that update finishes. Starting remains blocked by the existing readiness check until the saved resolution matches the selection.
- **Manual strokes shown as Index: round-wide presentation state.** The roster header and player subtitles consulted the round-wide entry format or the presence of a retained Index. A player can deliberately select manual strokes while retaining an Index for a later edit. Presentation must use that player's saved entry method.

## Scope and safeguards

- Share entry-method resolution across the roster header, numeric editor and player subtitles; saved league snapshots retain priority.
- Use the existing calculator to preview a changed selection only in the unstarted lobby. The preview never persists data or mutates an Index, manual strokes, gross scores or stroke allocations.
- Keep stored calculations for live/completed round presentation and frozen league values. An edited/cleared Index cannot display an old Course Handicap in setup.
- Keep Exact / Estimated / Unavailable behavior. A changed estimated calculation requires fresh approval; previewing it cannot reuse approval for different inputs. Explicit manual strokes remain available.
- Existing participant recomputation and activation validation continue to determine persisted allowances and scoring. No changes to league algorithms, commissioner overrides, caps, normalization, signed handicaps, handicap accrual, Settings, companion behavior or ordinary round history.

## Files changed

- `Hackers/Core/Scoring/ScoringService+Course.swift`: shared per-player entry-mode lookup and an opt-in current-selection preview; stored calculations remain the default.
- `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`: per-player roster/editor/subtitle modes, a mixed-mode HCP header, and lobby-only previews.
- `HackersUnitTests/RoundHandicapEntryTests.swift`: supplied reproductions plus mixed-mode serialization/navigation/allocation, missing input, estimate approval and historical/league regression coverage.
- `HackersUnitTests/HandicapKeyboardDismissalTests.swift`: production GameLobby hosted with local state; manual-only/mixed headers, per-player labels, 18 → front nine → back nine → 18 previews, unchanged participant records and screenshots. Existing registered/offline editor and keyboard Done tests remain enabled.
- `.github/workflows/score-carousel-tests.yml`: include entry, Course Handicap, hosted editor/lobby and ScoringEngine regression suites in the existing PR job.

## Simulator screen review

The passing hosted production lobby shows Index **17.7** unchanged, with Course HCP / strokes **8** on the front nine, **9** on the back nine and **16** on 18 holes. The other player's manual **12** stays unchanged and is labeled Strokes. These are local fixtures, not saved customer rounds or claims about official course data. The back-nine rating/slope are synthetic test inputs. The test deliberately retains the old saved participant records while validating the current selection preview.

| Selected holes | Production lobby screenshot |
| --- | --- |
| Front nine | [Index 17.7, Course HCP 8, manual strokes 12](pr16-course-handicap-fixes/front-nine.png) |
| Back nine | [Index 17.7, Course HCP 9, manual strokes 12](pr16-course-handicap-fixes/back-nine.png) |
| 18 holes | [Index 17.7, Course HCP 16, manual strokes 12](pr16-course-handicap-fixes/eighteen-holes.png) |

## Validation

October 18, 2026, Sandbox on iPhone 17 Pro Simulator, iOS 26.3.1, arm64:

- **Full HackersUnitTests suite: 1,032 passed, 0 failed, 5 existing opt-in skips.** Eight new regressions are included. Result bundle: `/private/tmp/HackersPR16ThreeBugs-full.xcresult`.
- All **140 focused cases** pass in the final suite: RoundHandicapEntryTests **24**, CourseHandicapCalculationRegressionTests **23**, HandicapKeyboardDismissalTests **14**, ScoringEngineTests **79**. The standalone production-lobby test also passes in `/private/tmp/HackersPR16ThreeBugs-lobby-final.xcresult`.
- Before the fix: `/private/tmp/HackersPR16ThreeBugs-before.xcresult` reproduces the stale 18-hole preview while offline default-tee and registered/offline real-editor cases pass. `/private/tmp/HackersPR16ThreeBugs-lobby-baseline.xcresult` reproduces the incorrect header/retained Index label and stale preview in the production lobby.
- Coverage includes registered/offline temporary inputs, distinct per-player tees, front/back/18-hole changes, mixed manual/Index mode, reopening and serialized state, missing ratings/slope/Index, approved and changed estimates, gross/net allocation, league nine-hole conversion, commissioner overrides, signed/plus allowances, caps and historical snapshots.
- Existing skipped opt-in cases: `LiveScorecardOCRDiagnosticTests/officialCourseCoverLookup`, `LiveScorecardOCRDiagnosticTests/bundledScorecard`, `CourseChatPreviewTests/renderStates`, `CourseTextLookupServiceTests/liveChatSearch`, `GolfCourseAPILiveDiagnosticTests/liveSearchAndDetail`. No new skips or disabled tests.
- `git diff --check` passes. The existing PR workflow now selects the four focused suites; hosted GitHub Actions results are separate from the local validation above.

**Standalone Sandbox simulator build, install and launch passed.** Bundle: `com.tigermindlabs.hackers.compete.sandbox`. Runtime UI inspection confirms launch reaches Apple/Google sign-in. Build log: `/Users/Kirsten/Library/Developer/XcodeBuildMCP/workspaces/Hackers-Combined-f7828574fa53/logs/build_run_sim_2026-10-18T19-36-53-515Z_pid11554_612359db.log`. Existing warnings (unused helpers, Swift 6 captures and existing recursion warnings outside the changed files) remain; no new build errors.

## Acceptance limits

Hosted simulator tests use the production editors and lobby with local snapshots. They do not authenticate with Firebase or create server-side rounds. Codable save/reload covers serialized state; signed-in Firestore persistence/listener timing and physical-device/TestFlight acceptance still require an internal acceptance pass. ClickUp's connector was rate-limited during this work, so ticket descriptions are taken from the user's supplied reproduction requirements; no ticket status was changed.

No GitHub PR merge, deployment, production-data change or TestFlight upload is part of this update.
