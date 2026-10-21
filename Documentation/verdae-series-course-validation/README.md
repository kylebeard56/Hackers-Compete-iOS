# Preserve at Verdae — series Course Handicap blocker

## Root cause and release attribution

The original signed-in Test HCP scheduling flow was reproduced on October 19: Create round reports missing rating/slope while the selected course has valid Blue tee data. [Before screenshot](before-blocker.jpg).

The series course picker, default-course callback, round-start persistence, and linked-course mapping preferred `golfCourseApiID` over the selected `CourseInfo.id`. A library document can have its own UUID and tees plus a provider reference. Persisting only the provider reference discards that document identity and causes subsequent validation to read a different course or fail to load it.

Read-only Sandbox SDK queries confirmed:

- Test HCP (`V6Egarw4RtsnnUNKSeM1oTubHFUH`) had no persisted default course before this work. The failing scheduling attempt had not saved a round.
- `courses/24833`: provider-origin course, Blue `blue_male`, 18 complete hole pars totaling 72, rating 72.2 / slope 137. Front/back ratings and slopes are absent. Nine-hole fallback calculations are estimated, not exact.
- There is no `courses/27322` document. Multiple UUID-backed library documents have origin `hackers`, provider reference 27322, and exact Blue 18/front/back values 72.2/137, 36.4/130, 35.8/143. Their tee IDs differ. One captured example is `MJSz56yWUkQ4Q4U8bWem9UVqBSVU`, Blue `EJjC3800YYR0fO2HRTriqiGCJ5xC`.
- These records are not interchangeable. No course aliases, automatic tee substitutions, data repairs, or fabricated ratings were written.

The code also initialized availability to false, converted loading failures into that same false value, let out-of-order requests replace newer checks, and silently selected the first tee for unmatched saved IDs. The generic error incorrectly asserted missing rating/slope even when loading or tee identity was the problem. The canonical calculator also requires complete segment pars, which the old message omitted.

This is a pre-existing defect, not a demonstrated PR #14/#16 regression. The lossy selection and Boolean/fallback implementation are already supported by commit `f590acd1` (September 3), before those PRs. PR #14's safe calculation rules must remain intact.

## Implementation

- `Round+Course.swift`: preserve the actual selected library document ID, using provider identity only when no document ID exists.
- `CourseSelectionConfirmation.swift`: retain that identity for series defaults.
- `SeriesRoundDraft.swift`: explicit checking, ready, load failure, tee unavailable, missing segment data, estimated, and no-course states; strict tee identity; shared document-first loader; canonical metadata calculation; request generation protection; typed persistence validation.
- `NewSeriesRoundSheet.swift` and `EditSeriesRoundSheet.swift`: keyed asynchronous checks independent of profile loading, specific feedback/retry, canonical rating/slope/par display, validation at save, and guarded submission without clearing draft state.
- `CourseSelectionForSeriesRoundSheet.swift`: same loader for saved courses; no automatic first-tee selection on reopen; retain the existing compact review.
- `SeriesRoundCreationService.swift`: same selected-document loader for live creation, explicit failure message, and no first-tee fallback.
- `SeriesViewModel.swift`: typed verified setup at persistence, shared duplicate-submission guard, and consistent course identity on live creation.
- `SeriesRoundCreationMapping.swift` / `SeriesRoundConfigurationReconciler.swift`: preserve the document through mapping and lobby reconciliation.
- `SeriesCourseHandicapValidationTests.swift`: 27 new regressions, including asynchronous prefill with a fresh UUID-bearing default model and preservation of concurrent user course/tee/hole edits.

Course Handicap calculations, personal 18-hole Index semantics, exact/estimated approval rules, series caps, normalization, gross/net scoring, team creation, and existing frozen snapshots are unchanged. A planned round can retain estimated metadata as before; estimated allowances are never implicitly approved, and series handicap preflight still requires exact data.

## Automated evidence

XcodeBuildMCP, Sandbox scheme/configuration, Hackers Handicap Tests simulator `C136E3C7-BE88-4383-85D3-163F366C7F60`, iOS 26.3.1:

- Read-only authenticated data diagnostics passed in `/private/tmp/HackersVerdaeBaseline.xcresult` and `/private/tmp/HackersVerdaeRecords.xcresult`. Public course evidence is retained in [sandbox-course-evidence.json](sandbox-course-evidence.json). The temporary live diagnostic is not part of the permanent unit-test target.
- Focused run: 93 passed, zero failed/skipped, `/private/tmp/HackersVerdaeFocused.xcresult`.
- Initial full suite: **1,123 passed, zero failed, five existing opt-in skips**, `/private/tmp/HackersVerdaeAll.xcresult`. After the prefill follow-up: **1,126 passed, zero failed, five existing opt-in skips**, `/private/tmp/HackersVerdaeFinal.xcresult`. **Final combined run on latest PR #16 (`5c5d9c03`): 1,136 passed, zero failed, five existing opt-in skips**, `/private/tmp/HackersVerdaeUpstreamCombined.xcresult`.
- All **27** new tests pass: supplied Verdae segment values; both provider references; actual record identity; 24833 estimated nine-hole metadata; stale/reused/absent tee IDs; rating/slope/par failures; independent segments; zero Index/manual strokes; new/saved/reopened drafts; unchanged drafts after failure; stale validation; retry; late course/tee responses; cancellation; revalidation; and actual live-round/participant payloads in gross/net configurations.
- All **11** prior stroke-dot tests pass. Their source is byte-identical to the original development checkout's test file. The existing dot patch was carried forward without edits.
- Existing compact review, commissioner, substitutions/attendance, stale/duplicate start, saved options, handicap basis, scoring, and frozen-round regression suites pass.
- `git diff --check` passes. No dependencies or Xcode project settings changed. Existing compiler warnings remain outside this change.

## October 20 upstream overlap review

Fresh GitHub reads confirmed PR #14 remains `140f22ce`, PR #15 remains `e9782443`, and main remains `731f5619`. PR #16 advanced from `897278c0` to `5c5d9c03`; PR #17 advanced from `be001f41` to `165b76e3`.

The new PR #16 commits fix mixed per-player entry recalculation, gross-only handicap preflight, frozen scoring-basis validation, and same-account companion restoration. PR #17 contains the same companion restoration change. Those implementations are retained; no parallel recalculation, companion, or frozen-basis implementation is added here.

There was one semantic overlap: the earlier local compact-review changes filtered optional gross-round handicap issues differently. That local `issues` implementation has been removed, and both `requiresHandicaps` and `issues` now match upstream `5c5d9c03` exactly. The readiness regression follows upstream gross-only behavior. Net-round validation remains strict.

The course-record fix remains necessary: none of the new commits modifies the selected library/provider identity, the default-false availability state, the course loader, or the first-tee fallback. Upstream still prefers the provider reference over the selected library document and uses the ambiguous availability Boolean. The new commits also do not implement the optional compact round-start confirmation.

The final combined full unit suite passed **1,136 tests, zero failed, five existing opt-in skips**, including all ten new upstream regressions, all 27 course-validation regressions and all 11 stroke-dot regressions. The test build and `git diff --check` passed.

Combined source was tested in detached checkout `/private/tmp/HackersPR16IndexEntry` at upstream `5c5d9c03`, with only the remaining local changes applied. The existing PR #16 development worktree was then fast-forwarded to that remote head, with the tested remaining local changes preserved and the overlap removed. Complete pre-integration patch/tar backups are under `/private/tmp/HackersPR16-before-upstream-integration-20261020`. The original development checkout and its uncommitted changes are untouched.

## Signed-in acceptance and limits

The rebuilt standalone Sandbox app installed and launched successfully. Signed-in Test HCP retained title `1` and Handicap Index scoring; recent-course selection and fresh search both reached Ready with Blue tees / Full 18 / rating 72.2 / slope 137 / par 72. Read-only LLDB inspection confirmed actual selected document `2petFWO6L40zc95XvacraA8N8wKp` and tee `tIoFlOmIGfJ8HaRSyKl6zX1wG9EV`, not a provider-ID alias or another tee. The stale-identity state requires explicit re-selection and does not substitute the first tee.

The read-only check also caught an additional implementation issue before finalization: `Course()` already has a UUID, so its `isEmpty` property cannot indicate whether a user has selected a course. Shared prefill now compares course/tee/segment checkpoints across the asynchronous load. Three new tests exercise that real production prefill helper.

The user subsequently authorized creation and cleanup of temporary Live Sandbox test data. Live planned-round persistence, compact Start Round creation, server readback, scoring and cleanup were exercised in isolated temporary series; see the [October 20 live acceptance report](live-sandbox-2026-10-20/README.md). The successful isolated rerun passed all four cases and removed 286 fixture documents. The first live run removed its 285 fixture documents but failed the preservation comparison for the existing Sandbox player record; automatic profile-cache refresh during normal session restoration is a likely source. That failure is retained in the report and must not be represented as an entirely unchanged first run. No corrective write to the existing record was attempted. Production data was not modified.

The Build iOS Apps transport closed during standalone build, and a CLI retry encountered a full disk. Only four redundant test-product packages created by this task were removed; all result bundles, logs, source, and evidence were retained. The standalone Xcode CLI build then succeeded. No merge, deployment, or TestFlight upload was performed.

Physical iPhone acceptance remains required on a future build containing this change: select the intended library record, verify Men's Blue and 18/front/back independently, retry a failed load, reopen a planned round, start once, compare persisted/live values, and verify existing historical snapshots remain unchanged.
