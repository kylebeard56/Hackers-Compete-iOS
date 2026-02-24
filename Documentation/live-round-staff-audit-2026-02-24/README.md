# LiveRound Staff Audit - February 24, 2026

This folder contains a deep, issue-by-issue audit of `Hackers/Features/Round/LiveRound`.

## Scope

- Focus area: `Hackers/Features/Round/LiveRound`
- Review type: static code analysis (no runtime instrumentation in this pass)
- Goals: identify code smells, orphaned logic, duplication, performance issues, and scaling risk

## Severity Rubric

- 90-100: Critical (correctness risk or severe UX/regression risk)
- 70-89: High (major performance, maintainability, or user-impact risk)
- 40-69: Medium (meaningful risk, usually not immediately user-blocking)
- 0-39: Low (cleanup or optimization, low immediate risk)

## Findings Index

1. [Split Hole State Can Write Scores To Wrong Hole](./01-split-hole-state-can-write-wrong-hole.md) - 98/100 (Critical)
2. [Score Lookup Is Linear In Hot Paths](./02-score-lookup-linear-in-hot-paths.md) - 95/100 (Critical)
3. [Heavy Per-Page Rendering Work Is Duplicated Across Hole Pages](./03-heavy-rendering-duplicated-across-hole-pages.md) - 90/100 (Critical)
4. [LiveHoleScoringView Uses Implicit Current Hole For Writes](./04-live-hole-scoring-uses-implicit-hole-for-writes.md) - 86/100 (High)
5. [Pager Width Math Is Inconsistent](./05-pager-width-math-is-inconsistent.md) - 82/100 (High)
6. [Orphaned And Duplicative Scorecard Surfaces](./06-orphaned-and-duplicative-scorecard-surfaces.md) - 80/100 (High)
7. [Unnecessary Writes On Golfer Switch](./07-unnecessary-writes-on-golfer-switch.md) - 76/100 (High)
8. [Hide-All Visibility Can Be Overwritten](./08-hide-all-visibility-can-be-overwritten.md) - 71/100 (High)
9. [Nested Button Structure In Leaderboard Row](./09-nested-button-structure-in-leaderboard-row.md) - 64/100 (Medium)
10. [Binding Lifecycle Risk In ViewModel](./10-binding-lifecycle-risk-in-viewmodel.md) - 58/100 (Medium)
11. [Dead/Diagnostic Logic In Production Path](./11-dead-and-diagnostic-logic-in-production-path.md) - 36/100 (Low)
12. [DateFormatter Allocation On Render Path](./12-dateformatter-allocation-on-render-path.md) - 28/100 (Low)

## Notes

- Code references in each file use absolute workspace paths.
- Confidence levels are included per issue where assumptions are required.
