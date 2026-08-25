# Series and Round V2

## Outcome

V2 removes the mutable `SeriesRound` shell from gameplay. A scheduled Series round is immediately a real document in `rounds-v2`; its optional `series_context` binds Series-specific defaults, policies, and result processing without making the round dependent on a second source of truth.

V1 remains unchanged in `series` and `rounds`. Existing V1 leagues keep creating V1 Series-round shells until their route explicitly selects V2 or they are migrated.

## Persistence shape

```text
series-v2/{seriesID}
  members/{memberID}
  teams/{teamID}
  pods/{podID}
  scoring-profiles/{profileID}
  round-results/{generationID}
  round-result-states/{roundID}
  standings/{standingID}

rounds-v2/{roundID}
  participants/{participantID}
  teams/{teamID}
  tee-groups/{groupID}
  scoring-groups/{groupID}
  segments/{segmentID}
  scores/{deterministicScoreID}

series-memberships-v2/{seriesID_playerID}
join-codes-v2/{shareCode}
commands-v2/{user_operation_commandID}
series-routing-v2/{sourceSeriesID}
```

There is zero or one Series binding per round. A scoreless standalone lobby can be adopted by a Series commissioner who also owns the round.

## State ownership

- Playable lifecycle: `lobby → live → completed → archived`.
- Pause and cancellation are orthogonal fields, not lifecycle states.
- Series result processing is independent: `pending`, `processing`, `needs_review`, `finalized`, or `failed`.
- Series tile state derives `pending`, `scheduled`, or `lobby` from schedule time and `lobby_activated_at`. The default lobby window is 24 hours.
- Series defaults are snapshots. A later defaults revision is previewed and explicitly applied; it never silently competes with round configuration.

## Write boundary

Callable functions own root creation, share-code reservation, structural provisioning, adoption, default application, and lifecycle transitions. Each command has a caller-generated id, a namespaced receipt, and an expected revision where appropriate. Retrying a command is safe.

Scores remain deterministic direct Firestore writes for live-round latency. Before enabling a V2 client route, the deployed Firestore rules must allow only eligible round participants/commissioners to write `rounds-v2/{roundID}/scores/*` while the round is live and not paused. This repository did not previously contain the deployed rules source, so `firebase.json` intentionally adds indexes without replacing the existing ruleset.

## Invisible cutover and deduplication

Migration routing progresses through `copying → validating → ready → active`, with `active → rolled_back` available for rollback. The route is server-owned, revision checked, and mirrored into Series V2 migration metadata.

Updated clients resolve both versions and return one logical `SeriesRecord`:

- `copying`, `validating`, `ready`, `failed`, or `rolled_back`: show V1 only.
- `active`: show V2 only; never silently fall back to stale V1.
- Native V2 Series without migration metadata: show V2 normally.

The same selector governs dashboard data, IDs, share codes, and Series-linked round links. Since migration preserves Series and round IDs/share codes, activation changes the backing model without creating a second user-visible league or invalidating existing links.

The current production Series screens still load V1 models directly. Do not move a route to `active` until those screens use the version-neutral `SeriesRecord` loading path and can open a selected V2 Series/round. Activation must also be protected by the app's minimum-version gate so an older V1-only client cannot continue presenting or mutating the legacy copy.

## Provisioning and roster behavior

New rounds are visible in `lobby` immediately with `provisioning.phase = provisioning`. The server then writes participants, Series teams, tee groups, scoring groups, and a segment using bulk writes before marking the aggregate `ready`. A failed command records a retryable failure state.

Series member changes propagate to lobby rounds and the membership index. Live rounds are immutable to roster propagation. Existing attendance and structural assignments are preserved when a member record changes.

## Migration runbook

The migrator is dry-run-first and uses the active Admin SDK project credentials.

```sh
npm --prefix functions run migrate:series-v2 -- --project FIREBASE_PROJECT --series SERIES_ID
npm --prefix functions run migrate:series-v2 -- --project FIREBASE_PROJECT --series SERIES_ID --write --minimum-client-version 2.x.y
```

The write pass:

1. Preserves the Series ID, linked round IDs, and all existing share codes.
2. Converts every planned V1 shell into a provisioned real V2 round; newly materialized rounds receive deterministic collision-checked share codes.
3. Copies members, teams, pods, membership indexes, canonical results, standings, scoring profiles, handicap data, and playable round subcollections.
4. Resolves V1 course selections into round-local course snapshots.
5. Maps paused gameplay to `live + scoring_paused` and maps completed gameplay to `completed`.
6. Creates a hidden `copying` route, compares every copied playable subcollection and canonical result document using stable semantic hashes, verifies all planned-round participants/segments, and only then advances the route to `ready` and stamps `migration.validated_at`.
7. Requires a minimum client version on every write migration.

Run the dry-run and write pass in the sandbox first. Recompute Series results with the V2 result processor and compare its semantic hashes to the preserved canonical V1 results before changing the app route or archiving V1. The migrator validates lossless transfer; route cutover remains a separate, reversible release action.

## Deployment order

1. Deploy composite indexes.
2. Merge and deploy V2 access rules into the authoritative Firestore rules source, including authenticated route reads and a post-cutover denial of V1 Series/linked-round writes for active routes.
3. Deploy functions and verify create/retry/transition behavior in the emulator or sandbox.
4. Ship a client that can read both versions but still creates V1 by default.
5. Ship the dual-version client so lists, detail screens, and links use migration-aware selection, then enforce its minimum app version before activation.
6. Dry-run, write, and result-validate the pilot league; it remains visibly V1 while the V2 copy is `ready`.
7. Activate its V2 route with the revision-checked commissioner command and monitor before migrating other leagues.
8. Keep V1 documents read-only through the rollback window; archive them only after confidence is established.
