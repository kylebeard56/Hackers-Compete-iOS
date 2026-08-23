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
