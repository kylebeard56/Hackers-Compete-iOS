# LiveRound Staff Audit (Combined)

Generated: 2026-02-24

Source folder: `Documentation/live-round-staff-audit-2026-02-24`

## Table Of Contents

- [01 - Split Hole State Can Write Scores To Wrong Hole](#01---split-hole-state-can-write-scores-to-wrong-hole)
- [02 - Score Lookup Is Linear In Hot Paths](#02---score-lookup-is-linear-in-hot-paths)
- [03 - Heavy Per-Page Rendering Work Is Duplicated Across Hole Pages](#03---heavy-per-page-rendering-work-is-duplicated-across-hole-pages)
- [04 - LiveHoleScoringView Uses Implicit Current Hole For Writes](#04---liveholescoringview-uses-implicit-current-hole-for-writes)
- [05 - Pager Width Math Is Inconsistent](#05---pager-width-math-is-inconsistent)
- [06 - Orphaned And Duplicative Scorecard Surfaces](#06---orphaned-and-duplicative-scorecard-surfaces)
- [07 - Unnecessary Writes On Golfer Switch](#07---unnecessary-writes-on-golfer-switch)
- [08 - Hide-All Visibility Can Be Overwritten](#08---hide-all-visibility-can-be-overwritten)
- [09 - Nested Button Structure In Leaderboard Row](#09---nested-button-structure-in-leaderboard-row)
- [10 - Binding Lifecycle Risk In ViewModel](#10---binding-lifecycle-risk-in-viewmodel)
- [11 - Dead And Diagnostic Logic In Production Path](#11---dead-and-diagnostic-logic-in-production-path)
- [12 - DateFormatter Allocation On Render Path](#12---dateformatter-allocation-on-render-path)

---

<!-- BEGIN: 01-split-hole-state-can-write-wrong-hole.md -->
# 01 - Split Hole State Can Write Scores To Wrong Hole

- Category: Correctness, State Management
- Severity: Critical
- Score: 98/100
- Confidence: High

## Problem Finding

Hole state is currently split between UI paging state (`scoringPageHole`) and ViewModel state (`currentHoleIndex`/`currentHoleNumber`). Mutations still depend on `currentHoleNumber`, which can drift from what the user is actually viewing.

## Evidence / Proof

- UI display source:
  - `@State var scoringPageHole: Int?` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:68](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:68)
- ViewModel source:
  - `@Published var currentHoleIndex` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:33](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:33)
  - `currentHoleNumber` derived from `currentHoleIndex` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:120](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:120)
- Sync direction is one-way:
  - `viewModel.currentHoleNumber -> scoringPageHole` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:168](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:168)
- Mutations still use implicit current hole:
  - `setQuickScore -> setScore(participant:strokes:) -> currentHoleNumber` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:793](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:793)
  - `clearScore(participant:) -> currentHoleNumber` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797)

## Why This Is A Problem

A user can page to Hole N while writes still target Hole M. This is a silent correctness bug that can corrupt score entry without obvious immediate UI errors.

## Assumptions / Validation Notes

- Assumes the pager can change visible hole without always updating `currentHoleIndex`.
- Assumption is supported by comments in code that explicitly separate these concepts.

## Recommended Fix

1. Make all score mutations hole-explicit (pass hole number at call site).
2. Add reverse sync guard: when `scoringPageHole` changes, call `viewModel.selectHole(_:)`.
3. Deprecate implicit mutation APIs that depend on `currentHoleNumber`.
4. Keep one source of truth for display (`scoringPageHole`) and one for business intent only if absolutely necessary.

## Implementation Steps

- Add:
  - `setQuickScore(participant:strokes,holeNumber:)`
  - use existing `clearScore(participant:holeNumber:)`
- Migrate call sites in:
  - `LiveHoleScoringView`
  - `ScorecardPopupView`
  - any other scoring UI
- Add a short regression test plan:
  - page to different holes, enter score, verify correct `ScoreEntry.holeNumber`.

<!-- END: 01-split-hole-state-can-write-wrong-hole.md -->

---

<!-- BEGIN: 02-score-lookup-linear-in-hot-paths.md -->
# 02 - Score Lookup Is Linear In Hot Paths

- Category: Performance, Scaling
- Severity: Critical
- Score: 95/100
- Confidence: High

## Problem Finding

`scoreEntry` performs a linear scan of `snapshot.scoring` and is repeatedly called inside loops and computed properties that feed rendering.

## Evidence / Proof

- Linear lookup:
  - `scoreEntry(for:holeNumber:)` uses `first(where:)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:365](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:365)
- Called from hot aggregate paths:
  - `holesPlayedCount` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:379](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:379)
  - `holeCompletionProgress` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:386](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:386)
  - `scoreToPar` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:422](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:422)
- These feed large UI sections (`leaderboardRows`, scorecard views), multiplying cost.

## Why This Is A Problem

Complexity trends toward O(participants * holes * scoringEntries). As rounds or participants grow, compute overhead increases sharply and can cause visible UI lag during updates/scrolling.

## Assumptions / Validation Notes

- Assumes non-trivial `snapshot.scoring` size and frequent recomputation under SwiftUI invalidation.
- Confidence high due to deterministic complexity and repeated call graph.

## Recommended Fix

1. Build a score index whenever snapshot changes.
2. Replace linear scans with O(1) dictionary reads.
3. Use that index consistently in all lookup helpers.

## Suggested Design

- Create cached map keyed by `(participantID, holeNumber)` or a compact string key.
- Rebuild once on snapshot update in `bind` sink.
- Keep existing APIs but route through index internally.

## Implementation Steps

- Add `private var scoreIndex: [ScoreKey: ScoreEntry]`.
- Populate in a `rebuildIndexes()` method called on snapshot update.
- Refactor `scoreEntry`, `grossStrokes`, `pickedUp`, and aggregate methods to use index.
- Add sanity checks in debug build to catch key collisions.

<!-- END: 02-score-lookup-linear-in-hot-paths.md -->

---

<!-- BEGIN: 03-heavy-rendering-duplicated-across-hole-pages.md -->
# 03 - Heavy Per-Page Rendering Work Is Duplicated Across Hole Pages

- Category: UI Performance, Architecture
- Severity: Critical
- Score: 90/100
- Confidence: Medium-High

## Problem Finding

Each hole page renders multiple heavy sections (detail tiles, tee-group score rows, leaderboard). This repeats expensive work across pages in the horizontal pager.

## Evidence / Proof

- Per-page composition in pager content:
  - `holeDetailsCard`, `teeGroupScorecard`, and `leaderboardSection` rendered for each page in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:51](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:51)
- `leaderboardSection` itself is non-trivial and recalculates ranking displays in multiple modes.

## Why This Is A Problem

Even with lazy containers, adjacent pages are realized and re-rendered as state changes. Duplicating leaderboard and player lists per page increases body computation and layout cost, which can manifest as swipe/paging lag.

## Assumptions / Validation Notes

- Assumes lag report is tied to rendering overhead (consistent with user report).
- Runtime profiling is still recommended to quantify exact contribution.

## Recommended Fix

1. Keep per-hole content only where hole-specific data is needed.
2. Move non-hole-specific heavy blocks (leaderboard) outside each page.
3. Memoize derived leaderboard rows/sections where possible.

## Implementation Options

- Option A: Render leaderboard once below pager and keep hole card + rows in page.
- Option B: Split view model into smaller observable slices so unrelated updates do not invalidate full page trees.
- Option C: Gate offscreen subtrees with lightweight placeholders until page approaches visibility.

## Implementation Steps

- Extract `leaderboardSection` to a sibling of `PagedHoleScrollView`.
- Keep scrolling behavior intact with shared vertical scroll only where needed.
- Re-test scroll smoothness and compare frame pacing.

<!-- END: 03-heavy-rendering-duplicated-across-hole-pages.md -->

---

<!-- BEGIN: 04-live-hole-scoring-uses-implicit-hole-for-writes.md -->
# 04 - LiveHoleScoringView Uses Implicit Current Hole For Writes

- Category: Correctness
- Severity: High
- Score: 86/100
- Confidence: High

## Problem Finding

`LiveHoleScoringView` receives an explicit `holeNumber`, but score mutation paths call view-model helpers that default to `currentHoleNumber` (implicit hole).

## Evidence / Proof

- Explicit hole parameter in view:
  - `let holeNumber: Int` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:20](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:20)
- Mutations using implicit helper:
  - `clearScore()` calls `viewModel.clearScore(participant:)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:447](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:447)
  - Multiple `setQuickScore(participant:strokes:)` calls in same file (e.g. lines 420, 461, 470, 480)
- Implicit helper routes to `currentHoleNumber` in ViewModel:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:797)

## Why This Is A Problem

If the view model current hole drifts from the sheet hole, score writes land on the wrong hole. This is a direct correctness bug with high user trust impact.

## Assumptions / Validation Notes

- No assumptions required for the bug shape; the call graph is explicit.
- Assumes drift can occur (confirmed by split-state architecture).

## Recommended Fix

1. Replace all implicit writes in `LiveHoleScoringView` with explicit-hole methods.
2. Use `viewModel.setScore(participant:holeNumber:strokes:)` and `viewModel.clearScore(participant:holeNumber:)` for this surface.
3. Optionally remove implicit APIs from ViewModel to prevent future misuse.

## Implementation Steps

- Introduce `setQuickScore(participant:strokes,holeNumber:)`.
- Update all score/clear call sites in this view.
- Add a manual test case: open sheet on Hole X while `currentHoleIndex` is Y and verify writes to X.

<!-- END: 04-live-hole-scoring-uses-implicit-hole-for-writes.md -->

---

<!-- BEGIN: 05-pager-width-math-is-inconsistent.md -->
# 05 - Pager Width Math Is Inconsistent

- Category: UI Performance, Interaction Quality
- Severity: High
- Score: 82/100
- Confidence: Medium-High

## Problem Finding

`PagedHoleScrollView` mixes fixed screen-width sizing with container-relative paging APIs. This can produce inconsistent geometry and subtle paging jitter.

## Evidence / Proof

- Child width hard-coded using screen width:
  - `.frame(width: UIScreen.main.bounds.width - 32)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/HolePager.swift:184](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/HolePager.swift:184)
- Also uses container-relative frame for same item:
  - `.containerRelativeFrame(.horizontal)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/HolePager.swift:186](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/HolePager.swift:186)
- Fractional index is derived from container width:
  - `contentOffset.x / containerSize.width` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/HolePager.swift:202](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/HolePager.swift:202)

## Why This Is A Problem

Mixing two layout models increases rounding and alignment drift risk. Indicator motion and settle points can feel less stable, especially on size class changes or embedded containers.

## Assumptions / Validation Notes

- Assumes this contributes to user-reported lag/jank.
- The mismatch is deterministic; exact impact should be measured in simulator/device traces.

## Recommended Fix

1. Use one geometry model for page width.
2. Prefer container-driven sizing for paging surfaces.
3. Remove `UIScreen.main.bounds` dependency from page item width.

## Implementation Steps

- Delete fixed width frame on item.
- Keep `.containerRelativeFrame(.horizontal)` and ensure parent width/padding is explicit.
- Verify page snapping and underline tracking under:
  - device rotation
  - split view / iPad
  - dynamic type changes

<!-- END: 05-pager-width-math-is-inconsistent.md -->

---

<!-- BEGIN: 06-orphaned-and-duplicative-scorecard-surfaces.md -->
# 06 - Orphaned And Duplicative Scorecard Surfaces

- Category: Maintainability, Product Surface Coherence
- Severity: High
- Score: 80/100
- Confidence: High

## Problem Finding

Multiple scorecard-related surfaces overlap in purpose, and at least two are currently orphaned/unwired from production flow.

## Evidence / Proof

- `ScorecardPopupView` appears disconnected from `LiveRound` flow:
  - hookup is commented in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:157](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:157)
  - usage appears only in preview in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardPopupView.swift:846](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardPopupView.swift:846)
- `ScorecardSheet` usage appears only in preview:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardSheet.swift:616](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardSheet.swift:616)
- Unused helper artifact:
  - `ScrollOffsetKey` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScrollOffsetKey.swift:10](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScrollOffsetKey.swift:10)

## Why This Is A Problem

Orphaned and duplicated pathways create drift in business logic and UX behavior, increase bug surface area, and slow future changes because developers must reason about dead or semi-dead code.

## Assumptions / Validation Notes

- Assumes no external dynamic wiring not visible in source.
- Confidence high due to repository-wide reference search.

## Recommended Fix

1. Choose one canonical score-entry/scorecard surface per use case.
2. Remove or archive orphaned implementations.
3. Centralize shared UI primitives and scoring logic.

## Implementation Steps

- Decision doc: keep `LiveHoleScoringView` + `FullScorecardView` (or alternate).
- Remove disconnected surface files once verified not needed.
- If retained for future use, move to a clearly marked experimental module with compile flags.

<!-- END: 06-orphaned-and-duplicative-scorecard-surfaces.md -->

---

<!-- BEGIN: 07-unnecessary-writes-on-golfer-switch.md -->
# 07 - Unnecessary Writes On Golfer Switch

- Category: Performance, Data Churn
- Severity: High
- Score: 76/100
- Confidence: High

## Problem Finding

Switching golfers in `LiveHoleScoringView` commits a score write unconditionally, even when no change occurred.

## Evidence / Proof

- In `jumpToPlayer`, write occurs every time:
  - `await viewModel.setQuickScore(participant: golfer, strokes: score)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:420](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LiveHoleScoringView.swift:420)
- No guard against unchanged draft vs saved score in this path.

## Why This Is A Problem

This increases network writes, local snapshot churn, and UI invalidations. In weak network conditions or larger groups, this can amplify lag and contention.

## Assumptions / Validation Notes

- Assumes `setQuickScore` leads to optimistic snapshot update + backend write (confirmed in view model write flow).
- Behavior is deterministic from code path.

## Recommended Fix

1. Use `shouldCommitScore` logic before writing on player switch.
2. Commit only when draft differs from saved score.
3. Optionally batch or debounce commits during rapid player switching.

## Implementation Steps

- In `jumpToPlayer`, compute `needsSave` before `Task`.
- Call write only when `needsSave == true`.
- Add smoke test:
  - switch golfers without changing picker value and verify no write call.

<!-- END: 07-unnecessary-writes-on-golfer-switch.md -->

---

<!-- BEGIN: 08-hide-all-visibility-can-be-overwritten.md -->
# 08 - Hide-All Visibility Can Be Overwritten

- Category: State Persistence, UX Correctness
- Severity: High
- Score: 71/100
- Confidence: High

## Problem Finding

Selecting "hide all" participants can be overridden by snapshot update logic that repopulates empty visibility to all participants.

## Evidence / Proof

- Auto-fill behavior when `visibleParticipantIDs` is empty:
  - in bind sink: [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:91](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:91)
  - in `set(snapshot:)`: [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:105](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:105)
- UI explicitly allows clearing all:
  - `draftVisibleIDs = []` flow in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardVisibilitySheet.swift:268](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/ScorecardVisibilitySheet.swift:268)

## Why This Is A Problem

User intent is not preserved. The app can appear to ignore explicit visibility settings after data refresh.

## Assumptions / Validation Notes

- Assumes empty set is a valid intentional state (supported by UI offering "Clear all").

## Recommended Fix

1. Distinguish "never configured" from "configured empty".
2. Only auto-populate on first initialization, not every empty-state snapshot update.

## Implementation Steps

- Add `hasInitializedVisibilitySelection` bool.
- Auto-fill only when false.
- Set true after first initialization or explicit user apply.
- Keep `lastAppliedVisibleParticipantIDs` logic consistent with this flag.

<!-- END: 08-hide-all-visibility-can-be-overwritten.md -->

---

<!-- BEGIN: 09-nested-button-structure-in-leaderboard-row.md -->
# 09 - Nested Button Structure In Leaderboard Row

- Category: UI Semantics, Accessibility, Interaction Bugs
- Severity: Medium
- Score: 64/100
- Confidence: Medium-High

## Problem Finding

`LeaderboardRowView` nests a star `Button` inside a row-level `Button`.

## Evidence / Proof

- Outer row button:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:27](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:27)
- Inner pin button:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:69](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/Accessory/LeaderboardRowView.swift:69)

## Why This Is A Problem

Nested controls can create ambiguous gesture routing and accessibility semantics. Users may trigger row navigation while trying to pin/unpin, depending on platform behavior and style.

## Assumptions / Validation Notes

- Assumes default SwiftUI nested button behavior without explicit containment handling.
- Exact behavior can vary by OS version and control style, but structure is broadly risky.

## Recommended Fix

1. Use a non-button container row (`HStack`) with explicit tap gesture for row open.
2. Keep star as the only `Button` in that subtree.
3. Add explicit accessibility labels and traits for row and pin control.

## Implementation Steps

- Replace outer `Button` with `contentShape(Rectangle()).onTapGesture`.
- Keep pin button and ensure it does not bubble row action.
- Validate with VoiceOver focus order and tap behavior.

<!-- END: 09-nested-button-structure-in-leaderboard-row.md -->

---

<!-- BEGIN: 10-binding-lifecycle-risk-in-viewmodel.md -->
# 10 - Binding Lifecycle Risk In ViewModel

- Category: Maintainability, Data Flow Stability
- Severity: Medium
- Score: 58/100
- Confidence: Medium

## Problem Finding

`bind(appSession:roundSession:)` guards against rebinding the same `roundSession`, but does not clear existing cancellables when binding a different session.

## Evidence / Proof

- Cancellable storage:
  - `private var cancellables: Set<AnyCancellable>` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:63](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:63)
- Rebind guard only for same instance:
  - `if self.roundSession === roundSession { return }` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:67](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRoundViewModel.swift:67)
- New sink appended, no `cancellables.removeAll()` before rebinding:
  - sink setup in lines 79-98 of same file.

## Why This Is A Problem

If the view model ever binds to multiple session instances over lifetime, duplicate sinks can keep old streams alive and apply conflicting updates.

## Assumptions / Validation Notes

- Assumes VM reuse across round sessions is possible in navigation flow.
- If VM is always recreated per round, risk is lower but still fragile.

## Recommended Fix

1. On bind to a different session, cancel and clear previous subscriptions.
2. Keep bind idempotent and explicit.

## Implementation Steps

- Add:
  - `if self.roundSession !== roundSession { cancellables.removeAll() }`
- Optionally split into:
  - `unbind()` and `bind()` for clearer lifecycle.

<!-- END: 10-binding-lifecycle-risk-in-viewmodel.md -->

---

<!-- BEGIN: 11-dead-and-diagnostic-logic-in-production-path.md -->
# 11 - Dead And Diagnostic Logic In Production Path

- Category: Code Hygiene, Runtime Noise
- Severity: Low
- Score: 36/100
- Confidence: High

## Problem Finding

There is production-path code that appears unused or diagnostic-only, including weather fetch dead path and snapshot debug printing in `.task`.

## Evidence / Proof

- Weather display checks `weatherService.currentSnapshot`:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:242](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:242)
- Weather fetch helper exists but appears unused:
  - `fetchWeatherIfNeeded()` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:396](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:396)
- Debug prints in runtime task:
  - `print("LIVE ROUND:")` and `printPretty(roundSession.snapshot)` in [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:153](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound.swift:153)

## Why This Is A Problem

Unused/dead code and debug prints add maintenance noise and can affect runtime logs/perf in aggregate, especially in frequently opened screens.

## Assumptions / Validation Notes

- Assumes no external side effects call `fetchWeatherIfNeeded()` via reflection/dynamic mechanisms (unlikely in SwiftUI path).

## Recommended Fix

1. Either wire weather fetch intentionally or remove weather display for now.
2. Gate debug prints behind debug-only compilation flags.
3. Remove stale commented pathways after confirming no active migration.

## Implementation Steps

- Use `#if DEBUG` for debug logs.
- Call `fetchWeatherIfNeeded()` at a clear lifecycle point if feature is active.
- Otherwise remove dead function and related display block.

<!-- END: 11-dead-and-diagnostic-logic-in-production-path.md -->

---

<!-- BEGIN: 12-dateformatter-allocation-on-render-path.md -->
# 12 - DateFormatter Allocation On Render Path

- Category: Micro-Performance, Code Quality
- Severity: Low
- Score: 28/100
- Confidence: High

## Problem Finding

`formattedLastUpdated` creates a new `DateFormatter` each time computed property is evaluated.

## Evidence / Proof

- Formatter allocation inside computed property:
  - [/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:320](/Users/kylebeard/Developer/Hackers-Compete-iOS/Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift:320)

## Why This Is A Problem

`DateFormatter` creation is relatively expensive. Repeated allocations in render paths are avoidable and increase overhead during frequent view updates.

## Assumptions / Validation Notes

- This is a low-impact optimization compared to larger structural issues.
- Included because it is an easy cleanup with no downside.

## Recommended Fix

1. Cache a shared formatter (static let) or use modern `FormatStyle` APIs.
2. Keep formatting locale-aware and test under 12/24h settings.

## Implementation Steps

- Add a static formatter in extension scope.
- Replace per-call allocation with shared instance.
- Verify output unchanged.

<!-- END: 12-dateformatter-allocation-on-render-path.md -->

---

