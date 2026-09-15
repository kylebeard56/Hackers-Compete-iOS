# Codex branch review — September 7, 2026

**Recommendation: request changes before merging.** The work improves useful parts of live play, but the combined candidate has a reproducible readiness defect and changes Production Watch packaging. PR #6 also omits the latest two commits of PR #5, creating an integration conflict.

Reviewed against `origin/main` at `f590acd14c127e7e9b589cbeec5691583073ea40`, after fetching the remote. Commit authors are **Kirsten Dauterive**; PRs were opened by **MountainHoundLabs**. Dates below are branch-tip committer dates in America/New_York (EDT), not independently verified push timestamps. Git does not retain branch push timestamps.

| Latest commit (EDT) | Branch | Tip | PR and status | Scope vs main |
|---|---|---|---|---|
| Sep 7, 8:10 AM | `codex/Gross_Scoring_Score_prediction_Update` | `c91d9f41` | [#6](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/6), open | 28 commits, 22 files, +1,155 / −487; combined live-round work and player charts |
| Sep 7, 6:55 AM | `codex/sandbox-pr2-pr3` | `b567523a` | [#5](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/5), open | 13 commits, 13 files; matchup improvements, Firebase startup, carousel and paging |
| Sep 6, 9:11 PM | `codex/fix-live-round-resume-wdx6zf0n01` | `410b7f69` | [#4](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/4), open | 7 commits, 11 files; durable resume, live loading, Overview, scan resizing |
| Sep 6, 8:54 AM | `codex/score-carousel-fix` | `7ba95375` | [#3](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/3), closed, unmerged | 3 commits, 6 files; earlier carousel fix and focused CI |
| Sep 4, 4:56 PM | `codex/head-to-head-insights-update` | `baf9549f` | [#2](https://github.com/kylebeard56/Hackers-Compete-iOS/pull/2), closed, unmerged | 1 commit, 5 files; expandable matchup summaries and scorecard styling |

PRs #2 and #3 are explicitly superseded by #5. Every branch is zero commits behind the inspected main, and GitHub reports each individually mergeable. That only establishes textual compatibility with main.

## Findings

### 1. P1 — Lobby → Live Round can wait indefinitely for already-loaded listeners

Applies to **#4 and #6**. Evidence: [RoundSession.swift:216](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/c91d9f41c032392c60054f10e5fa8a7bd45964fc/Hackers/Core/Round/RoundSession.swift#L216), [profile transition](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/c91d9f41c032392c60054f10e5fa8a7bd45964fc/Hackers/Core/Round/RoundSession.swift#L298), [readiness reset](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/c91d9f41c032392c60054f10e5fa8a7bd45964fc/Hackers/Core/Round/RoundSession.swift#L389), and [LiveRound readiness gate](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/c91d9f41c032392c60054f10e5fa8a7bd45964fc/Hackers/Features/Round/LiveRound/LiveRound.swift#L357).

The new warm-session condition allows live-round activation to reuse the lobby session. Transitioning profiles clears all readiness tracking and expects all seven listener types. Six lobby listeners are retained: their start methods return immediately when registrations already exist. Only the scoring listener is newly attached and guaranteed to deliver its initial snapshot. Unchanged teams, participants, segments, and groups need not emit again.

The new screen refuses to reveal scoring controls until every type has reported ready. Its polling loop has no timeout or failure state. Starting a round from a fully loaded lobby can therefore remain at “Loading score entry…” indefinitely. Failed/deleted/inaccessible round loads can also remain in this loop.

**Validation:** An executable Swift probe using the exact enums and readiness methods from #6 reproduced six ready lobby types becoming just one ready type after transition; `isScoringSnapshotReady` remained false. This is a source-derived state-machine reproduction, not a device UI reproduction.

**Fix direction:** Preserve the ready set for retained, successfully loaded listeners when transitioning, and wait for newly required listeners. Alternatively, deliberately reattach the full set. Add a recoverable load-error state while keeping scoring disabled until its snapshot is valid.

```swift
// Before: transition clears readiness for retained listeners.
initialLoadReadyTypes = []

// After: transition-specific seeding; preserve only verified readiness.
initialLoadReadyTypes = previousReadyTypes.intersection(retainedListenerTypes)
```

Regression coverage should drive a real lobby-to-live transition with unchanged retained collections, plus missing documents and listener errors. Existing tests exercise fresh tracking and saved-hole restoration separately and do not cover this transition.

### 2. P1 — Watch companion packaging is removed from Production too

Applies to **#2, #3, #5, and #6**. Evidence: [project.pbxproj:2057](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/c91d9f41c032392c60054f10e5fa8a7bd45964fc/Hackers.xcodeproj/project.pbxproj#L2057) and the [Production scheme](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/c91d9f41c032392c60054f10e5fa8a7bd45964fc/Hackers.xcodeproj/xcshareddata/xcschemes/Production.xcscheme).

The change removes both `Embed Watch Content` and the Watch target dependency from the shared `Hackers` app target. PR descriptions call this a Sandbox/test-host adjustment, but that same target serves both Sandbox and Production. A normal Production archive will no longer embed its Watch companion through the existing build graph.

**Validation:** Parsed both project versions: main has Watch and Live Activity dependencies and Watch embedding; #6 retains only the Live Activity dependency. Both configurations use the same app target.

**Fix direction:** Restore the Production Watch dependency and embedding; isolate the simulator test-host workaround through a dedicated target or appropriately scoped packaging setup. Verify an actual Production archive contains `Hackers.app/Watch/Hackers Watch App.app` and validate the companion flow before shipping.

```text
Before: shared Hackers target loses Watch dependency + Embed Watch Content.
After: Production retains both; simulator test host has a scoped configuration.
```

If dropping the Watch companion is intentional, treat it as an explicit product/release change rather than a test-only fix.

### 3. P2 — PR #5 alone removes live standings and Vegas context

Applies to **#5 as an independent merge**. Evidence: [LiveRound+Scoring.swift:56](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/b567523ab1cc35e1bf94cdd187841f6bb82c78e2/Hackers/Features/Round/LiveRound/LiveRound%2BScoring.swift#L56).

The last two paging commits remove the calls rendering the leaderboard, series scoreboard, and Vegas summary. This branch still has main’s old Table screen, which embeds only `FullScorecardView`. It does not contain #4’s Overview replacement. Consequently, merging #5 alone removes these live surfaces rather than relocating them.

**Fix direction:** Integrate #4’s corrected Overview implementation together with this change, or retain the existing standings/summary views until their replacement is present. #6 already has the replacement Overview, but still needs the later paging changes reconciled.

```text
Before: remove scoring-page standings while Table remains a scorecard only.
After: add Overview standings and Vegas context before removing the old surface.
```

### 4. P2 — Gross scoring radar exaggerates small and zero categories

Applies to **#6**. Evidence: [FullScorecardView.swift:2628](https://github.com/kylebeard56/Hackers-Compete-iOS/blob/c91d9f41c032392c60054f10e5fa8a7bd45964fc/Hackers/Features/Round/LiveRound/Accessory/Sheets/FullScorecardView.swift#L2628).

The new normalization renders a zero count at 12% radius and applies a 20% offset to every positive count. With a largest category of 10, a category containing one hole renders at 28% radius rather than 10%. Even an all-zero dataset produces a filled polygon. Count labels remain correct, but the chart shape no longer represents their relative frequency.

**Fix direction:** Keep the useful five-category ordering and colors, restore proportional values, and solve visibility with separate markers or labels. Show an explicit empty state for no scores.

```swift
// Before
return count == 0 ? 0.12 : 0.2 + CGFloat(count) / CGFloat(maximumCount) * 0.8

// After
return CGFloat(count) / CGFloat(maximumCount)
```

## Integration assessment

- **#4 + #5:** A dry-run `git merge-tree` succeeds without textual conflicts. The runtime readiness and Production packaging findings still apply.
- **#6 + latest #5:** A dry-run merge produces a content conflict in `Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift`.
- **#6 contains all of #4**, but its merged #5 history stops at `64a7fa21`. It omits `b592a534` (“Use one pager for the full score entry page”) and `b567523a` (“Disable vertical scrolling on score entry”). Its claim to contain complete #5 is stale relative to today’s branch tip.
- #6 received another commit during this review: `c91d9f41` (8:10 AM EDT) independently removes vertical scrolling. It retains a fixed outer stack and separate lower-area swipe gesture. Latest #5 places the score-entry page into one horizontal pager instead. The merge conflict still reproduces at the newest #6 tip. Reconcile the intended pager behavior instead of blindly replaying both commits.
- #2 and #3 contain superseded versions of work carried into #5/#6. Do not independently merge all five branches. Commit hashes differ where work was replayed, so assess net changes as well as ancestry.

**Recommended path:** Use #6 as the integration candidate, reconcile the remaining pager differences with #5, fix readiness and Watch packaging, and correct the radar scale. Then validate and merge one combined candidate. Reconcile the remaining open PRs after confirming the intended changes are included.

## Feature value and follow-up priorities

**Highest value:** Durable per-round hole restoration addresses a real wrong-hole scoring risk. Capturing player, score, and hole before asynchronous writes is sound. The clearer Exit versus Finish actions and moving standings to Overview fit the on-course workflow well.

**Useful input improvements:** A shared draft binding, immediate player selection, actual stroke labels in friendly mode, and allowing 1/2 on par-5 holes are worthwhile corrections. Validate rapid swipes followed immediately by Continue, repeated player switches, saved-score edits, clearing, shared-score groups, and airplane-mode entry. The four carousel tests validate numeric mapping, not gesture behavior or write ordering. Consider an unobtrusive pending/failed save indicator so immediate advancement remains understandable when persistence fails.

**Useful analytics improvements:** Expandable matchup summaries, direct player access, accessible team accents, net defaults when handicaps are on, an Even reference, and an explicit projected interval improve readability. Preserve those changes. Add fixtures for negative net totals, completed rounds, shotgun starts, skipped holes, and empty/low-history projections. The projection chart still combines course-order calculations with “holes completed” presentation; validate those cases before treating the display as correct for every play order. This latter concern is not reported as a newly introduced simulator defect because the underlying ordering predates these branches.

**Paging decision:** The single-pager approach has simpler gesture ownership. Removing vertical scrolling needs device checks for compact screens, larger text, and larger tee groups so lower controls remain reachable. This is a required visual validation item, not a confirmed clipping defect from this review.

## Validation record

- Refreshed remote branches and read PR metadata for #2–#6.
- Reviewed changed source, callers, project configurations, and added tests against main.
- Performed merge simulations in an isolated local clone; no branches were merged into the working checkout.
- `git diff --check` passed for all five branches against main, including the refreshed #6 tip.
- Source-derived Swift readiness probe reproduced the retained-listener wait.
- PR #5 tip has a successful [Score Carousel Tests run](https://github.com/kylebeard56/Hackers-Compete-iOS/actions/runs/34113992718). Its workflow selects only `ScoreCarouselSelectionTests` (four helper tests).
- Local Xcode 27 beta / iOS 26.4 Simulator run on `4b7df06b`: **11 tests passed** (four `ScoreCarouselSelectionTests` and seven `RoundSessionLifecycleTests`), exit code 0. This run did not execute the resume/analytics classes; the filename-based analytics filter did not name an XCTest class.
- Updated the isolated source copy to `c91d9f41` and invoked the actual resume, player-analytics, projection-integration, resume-store, carousel, and lifecycle test classes. App and test bundle compiled and linked without errors. The runner produced no live results for several minutes, so the run was interrupted (exit 75). Buffered output then reported **14 passing tests** (the same 11 carousel/lifecycle tests plus three projection-integration tests). It also marked `testMatchupTimelineReplaysEveryRecordedCheckpoint` failed during the interrupted run. Without an uninterrupted reproduction, this is an inconclusive test result, not a confirmed branch defect. Xcode also emitted a `simctl` lookup error during interruption. **Do not treat the expanded suite as passed; resume and remaining analytics coverage is unverified.** Logs: `/private/tmp/hackers-codex-review-latest-tests.log`; earlier successful run: `/private/tmp/hackers-codex-review-xcodebuild.log`.
- Latest #6 [CI run](https://github.com/kylebeard56/Hackers-Compete-iOS/actions/runs/34120394914) was still in progress when checked. The preceding #6 run was cancelled after the newer push.
- Production archive contents, Watch execution, and live gesture behavior were not tested. Simulator compilation does not establish correctness for those release/device paths.

Review findings and suggested fixes have not been posted to GitHub. Application source and existing staged changes were left intact.
