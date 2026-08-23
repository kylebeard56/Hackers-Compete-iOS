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
