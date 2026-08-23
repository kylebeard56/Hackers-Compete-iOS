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
