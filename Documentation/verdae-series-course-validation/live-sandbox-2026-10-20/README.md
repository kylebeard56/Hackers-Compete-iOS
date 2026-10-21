# PR #16 — authorized Live Sandbox acceptance, October 20, 2026

## Result

The four live functional cases passed against `hackers-compete-sandbox`, using actual Firestore server reads, production SwiftUI screens, the real draft/save/start services, and the unchanged scoring pipeline. The isolated acceptance run passed one test with zero failures or skips. Its fixture contained four rounds, four participants per round, and 216 score entries. All 286 fixture documents, including the temporary series/player, were deleted and their absence verified from the server. Across both live runs, all **571** created fixture documents were removed, including eight linked rounds and two temporary series. Five existing documents compared equal before/after this isolated run.

This result does **not** erase the first run's preservation failure, described below.

## Course, UI and scoring checks

The selected course document was `2petFWO6L40zc95XvacraA8N8wKp`, provider reference 27322; Men's Blue was `tIoFlOmIGfJ8HaRSyKl6zX1wG9EV`. Both identities survived planned-round saving, reopening and live-round creation. There is no numeric `courses/27322` document. Numeric record 24833 loaded successfully for 18 holes; its nines remained estimated because that separate record lacks exact segment metadata. A stale tee ID was explicitly unavailable and did not select the first tee.

| Case | Rating / slope / par | Index 17.7 strokes | Gross / net with one bogey per hole |
| --- | --- | --- | --- |
| 18 holes, net | 72.2 / 137 / 72 | 22 | 90 / 68 |
| Front nine, net | 36.4 / 130 / 36 | 11 | 45 / 34 |
| Back nine, net | 35.8 / 143 / 36 | 11 | 45 / 34 |
| 18 holes, gross | 72.2 / 137 / 72 | 22 | 90 / 68 |

Each case also contained offline personal Index zero, manual 12 strokes, and manual zero strokes. The Index remained 17.7; manual 12 stayed 12 over each selected segment; both explicit zeros were ready. Gross competition retained the same allowance and correctly calculated both gross and net projections from the same persisted scores. Scoring result totals are relative to par; the table expresses the corresponding stroke totals.

New-selection and saved-course paths displayed **Ready to Start**, **4 of 4 players ready**, collapsed completed rows, optional Edit Handicaps and one Start Round action. Temporarily removing one offline input displayed **Handicap Setup Needed** and expanded exactly one editor. Settled read-only captures were generated after the presentation animations, with an explicit check that the primary action has a nonempty frame contained in the window. Representative captures were visually inspected: [18 holes](compact-18-net.png), [front nine](compact-front-net.png), [back nine](compact-back-net.png), [gross basis](compact-18-gross.png), [one missing](one-missing.png).

Repeated Start activations and a subsequent duplicate API call produced exactly one live-round document per case. No existing series or profile values supplied fabricated test inputs; all input edits belonged to the temporary series rounds.

## Failures and test isolation

1. The first acceptance build failed on a test-harness typo (`primaryGameFormat` instead of `primaryFormat`). It was corrected before any live operations ran.
2. The first live run passed the functional assertions and removed all 285 fixture documents, but failed the before/after comparison for the existing signed-in Sandbox player document. The other four protected documents matched. The initial field-level baseline was not retained, so an exact before/after field diff is unavailable. No corrective write or restoration was attempted on that existing record.
3. Source inspection found automatic personal-handicap refresh during normal session restoration: `PersonalHandicapSection.loadHistory` calls `fetchPersonalHandicapHistory`; its implementation writes the personal-handicap refresh token and calculated cache. This is a likely source of the observed difference, not evidence that the round-only inputs changed the permanent Index. The later read-only audit shows calculation time `2026-10-21T00:47:30Z`, before the first fixture round was created at `00:47:39Z`; the player last-updated date remains October 15 and both manual/effective Indexes remain 17.7. This timing supports session-start cache refresh as the source. No temporary-round references remain in the player or its personal-handicap history. The first run cannot be described as complying fully with the no-existing-record-changes requirement.

For the successful rerun, an environment-gated guard temporarily suppressed automatic session restoration in the validation checkout. Authentication remained available for authorized SDK operations. The harness created a temporary registered player and used an in-memory user projection referencing only that player; it never saved the projection over the existing user. All round creation, preflight, handicap and scoring code remained unchanged. The temporary guard and executable acceptance test are removed from the deliverable source after validation. Original `AppSession.swift` SHA256 is `1cd5311528a3ec01f46b18268dfc92866fda2819a16dc17de478cccf7e24eefb`; all app Swift files compare byte-for-byte with the reconciled PR #16 worktree. A copy of the [opt-in diagnostic source](LiveSandboxAcceptance.swift) is retained outside the test target; it requires the explicitly isolated host and must not be run as an ordinary signed-in app test.

## Evidence

- First functional run with preservation failure: `/private/tmp/HackersPR16LiveSandbox-v2.xcresult`; [correctly marked first-run manifest](first-run-manifest.json).
- Successful isolated run: `/private/tmp/HackersPR16LiveSandbox-isolated.xcresult`; [cleanup/persistence manifest](isolated-run-manifest.json).
- Full regression rerun: **1,137 passed, zero failed, five existing opt-in skips**, `/private/tmp/HackersPR16SandboxRegression.xcresult`. This includes all 1,136 existing tests plus one read-only reference check. The live-write acceptance method was explicitly excluded. This rerun used the same temporary session-restoration suppression to prevent automatic profile-cache writes. The earlier uninstrumented combined-source suite remains **1,136 passed, zero failed, five skipped**, `/private/tmp/HackersVerdaeUpstreamCombined.xcresult`. No handicap, scoring, preflight or round-start service was instrumented.
- Settled read-only UI run: **1 passed, zero failed/skipped**, covering all five states and the visible primary action, `/private/tmp/HackersPR16StableVisual.xcresult`. It created no backend data.
- Read-only audit passed: [metadata](read-only-player-metadata.json) confirms manual and effective Index 17.7, no references to the first four temporary rounds on the player or in its personal-handicap scores/history, and absence of those round documents on the server.

## Scope and limits

No production Firebase app was initialized by the harness. Project/bundle/environment guards ran before the fixture writes. No production data, business rules, handicap formulas, team behavior, frozen snapshots or scoring rules were changed. No push, GitHub PR merge, deployment or TestFlight upload was performed.

The live exercise created linked lobby rounds through the real series Start Round flow and persisted synthetic scorecards in those fixtures. It did not complete real rounds, publish personal handicap history, exercise paired Watch delivery, or run on a physical iPhone. The existing Test HCP series was read/protected; it was not used as a writable fixture.

## Deliverable source state

Validation targets reconciled PR #16 head `5c5d9c03` plus the existing local course-validation/compact-review/stroke-dot changes. PR #14 `140f22ce`, #15 `e9782443` and the #17 companion restoration implementation remain preserved in that stack. Validation added documentation and evidence only. All app and existing test Swift sources compare byte-for-byte with the reconciled PR #16 worktree; the temporary test-host guard and executable live tests have been removed. `git diff --check` passes. No push, commit, PR merge or deployment was performed during this validation.
