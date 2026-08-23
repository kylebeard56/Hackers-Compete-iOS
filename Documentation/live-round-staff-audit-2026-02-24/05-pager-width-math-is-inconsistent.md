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
