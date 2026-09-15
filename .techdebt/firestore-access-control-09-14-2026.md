# Firestore access control while preserving anonymous guests

Date: 2026-09-14 (America/New_York)
Status: Open — documented for future implementation; no remediation deployed
Priority: High security debt; recommended release gate before broad distribution
Affected projects: `hackers-compete` and `hackers-compete-sandbox`

## Decision and product constraints

- The app is currently distributed through TestFlight to approximately 40 trusted beta testers. The Firebase project named production is not evidence of a public App Store launch.
- The owner explicitly requested documentation only. Do not interpret this document as authorization to change rules, authentication, data, infrastructure, or deployed functions.
- Guest access is crucial and must remain supported through **Firebase anonymous authentication**. Requiring Apple/Google sign-in for every user is not an acceptable fix.
- Preserve the existing round, series, scoring, and guest experiences. Use the existing Firebase architecture and make only the changes necessary to enforce its permissions.

## Summary

The alert is accurate about the deployed Firestore rules. Production allows reads and writes to every document without authentication. Sandbox allows the same except for the `courseAIUsage` collection and its descendants.

This is a database authorization issue. The TestFlight audience limits app distribution, but it does not restrict who can make requests to the Firebase backend. The rules themselves do not enforce the 40-person beta audience. This review did not verify other possible controls such as current App Check enforcement.

The earlier AI work deliberately preserved the existing broad application policy while protecting its new quota counters; it did not establish that the broader policy was safe or required. The production rule contains a comment about a 30-day expiry, but its actual condition is `true`, with no expiry check.

No evidence of exploitation was established. This investigation inspected deployed rule sources and local code, not document contents, access history, backups, or data integrity. Exposure, actual access, and confirmed compromise are different findings.

## Verified evidence

On 2026-09-14, the active `cloud.firestore` release and its referenced ruleset were fetched through the Firebase Rules REST API using the existing authorized Google Cloud account. These are live release findings, not assumptions based on the working tree. Re-fetch them before implementation; this document is a dated snapshot.

| Project | Active ruleset ID | Release last updated (UTC) | Effective rule |
| --- | --- | --- | --- |
| `hackers-compete` | `9e2a97d5-2adc-4725-809e-30525ba9cddd` | `2026-04-01T15:53:48.935570Z` | Unconditional read/write on all documents |
| `hackers-compete-sandbox` | `2f895f6f-d4ca-41ed-9b82-dc97aab78764` | `2026-09-14T19:01:29.999905Z` | Unconditional read/write outside `courseAIUsage` |

Production's operative match:

```text
match /{document=**} {
  allow read, write: if true;
}
```

Sandbox's operative match, also present in the local `firestore.rules`:

```text
match /{collection}/{document=**} {
  allow read, write: if collection != 'courseAIUsage';
}
```

The recursive matches include nested subcollections. `read` covers document reads and queries; `write` includes creation, updates, and deletion. The sandbox exclusion works because the broad allow condition excludes that collection. Adding a separate deny underneath an unconditional allow would not work: matching allow expressions are combined permissively. [Firebase rule behavior](https://firebase.google.com/docs/rules/rules-behavior)

`firebase.json` references one shared `firestore.rules`. `.firebaserc` defines `sandbox` and `production` aliases, with sandbox as the configured default. A selected CLI project can differ from that default, so future deployment commands must specify the project explicitly.

## Authentication is necessary, but not sufficient

| Requester | Firebase identity | Intended treatment |
| --- | --- | --- |
| Signed out | `request.auth == null` | Deny private application data; narrowly allow only deliberately public bootstrap values if needed |
| Anonymous guest | Authenticated UID; anonymous provider | Allow the guest's authorized round/series actions |
| Apple/Google user | Authenticated UID; linked provider | Allow owned data and authorized shared activity |
| Backend using Admin SDK | Service identity governed by IAM | Enforce authorization inside callable handlers; Firestore client rules do not protect these operations |

Firebase anonymous accounts can access data protected by rules without requiring a conventional sign-up. An authentication check such as `request.auth != null` includes these guests. [Anonymous authentication on Apple platforms](https://firebase.google.com/docs/auth/ios/anonymous-auth)

Replacing `true` with `request.auth != null` would remove tokenless access, but would still give any accepted account access to everyone else's data if used as the sole database-wide rule. Anonymous account creation makes this particularly inadequate. Do not mark this debt resolved by adding only an authentication check. [Avoid insecure rules](https://firebase.google.com/docs/rules/insecure-rules)

Likewise, the presence of an Apple/Google credential does not establish membership in the trusted beta group or authority over another user's round.

## Repository findings that shape the fix

Paths below are relative to the repository root.

| Area | Evidence | Implication |
| --- | --- | --- |
| Guest authentication | `Hackers/Core/Firebase/Collections/Firebase+Auth.swift` calls `signInAnonymously()`; `Hackers/App/Session/Session+Auth.swift` exposes the anonymous login path | Preserve this identity mechanism |
| Normal code-entry flow | `Hackers/Features/Onboard/Auth/AuthView.swift` authenticates anonymously before presenting “Join with code” | This path already supports requiring a Firebase token before lookup |
| Alternate entry paths | `FindRoundView.swift` handles deep links and freeform lookup; round/series view models fetch full target documents and rosters | Audit every entry path for auth readiness; do not assume the normal button is the only route |
| Guest round claim | `JoinRoundViewModel.continueAsGuest()` enters the round and assigns local `ephemeralParticipantID` | The inspected claim path does not persist a UID-based access grant; local state alone cannot authorize Firestore writes |
| Guest series entry | `JoinSeriesViewModel.continueAsGuest()` enters the loaded series | Establish what server-verifiable access permits this guest to read or modify |
| Private account lookup | `Firebase+User.swift`, `AuthService.swift`, and `Session+Load.swift` query users by email | Owner-only rules must be coordinated with UID-based lookup; changing rules alone can break sign-in and restore |
| Profile data | `HackersUser.swift` includes email, legal acceptance, metadata, credits, and status | Do not treat the full user document as a public player profile or let users modify server-owned fields |
| Player records | `Player.swift` includes optional `user_id`, names, histories, and offline-player support | Model registered ownership and guest/offline control separately; nil ownership must not mean public write access |
| Round ownership | `Round.swift` contains `created_by` and player IDs | Verify actual ID semantics and legacy data before using them as authorization inputs |
| V1/V2 coexistence | `FirebaseService.swift`, `SeriesRoundV2.swift`, and `Firebase+SeriesRoundV2.swift` define and route multiple collection families | Cover every active version; a V2-only fix leaves V1 exposed |
| Server role checks | `functions/series-round-v2.js` checks commissioner UID/member roles | Protect the source membership/role documents from client forgery, or callable authorization can be bypassed indirectly |
| Configuration | `Firebase+Config.swift` reads legal/version settings and writes `share_code_length` | Audit pre-auth reads and move or narrowly validate the client-side share-code length update |
| AI counters | `functions/course-ai.js` uses Admin SDK quota counters and rejects anonymous AI requests | Preserve client denial of counters; guest gameplay support does not imply expanding paid AI access |
| Existing rules tests | `functions/test-course-ai-rules.py` expects unauthenticated `courses` and `rounds` access to succeed | Replace those expectations when implementing; this suite currently validates the old policy, not application security |

The guest requirement corrects an overly broad interpretation of “public access needed”: guests need authenticated, scoped access. They do not require unrestricted access by requests without a Firebase identity.

## Proposed authorization policy

This is a target for future implementation, not a deployable rules file. First reconcile it with the existing permission helpers, gameplay behavior, and actual data. Specific guest scoring and participant-claim decisions remain listed below.

| Data | Proposed reads | Proposed writes |
| --- | --- | --- |
| `configuration` | Exact bootstrap document allowlist where needed; other settings only as required | Trusted backend/admin; handle share-code length explicitly |
| `users/{uid}` | Own private account | Own approved profile/consent fields; deny changes to server-owned credits/status and identity fields |
| `players` | Only profile/history data required by authorized discovery or shared play | Authorized owner or round/series workflow; protect user bindings and derived histories |
| `courses` | Authenticated registered users and guests as required by course selection | Preserve authorized course contribution/editing with field validation; define who may modify/delete existing shared courses |
| `rounds`, `rounds-v2` and children | Authorized participants, hosts, and scoped spectators | Match current host/scorer/participant permissions; validate lifecycle, scoring scope, and immutable ownership |
| `series`, `series-v2` and children | Authorized members and scoped guests/spectators | Match commissioner/member permissions; protect role assignment, derived results, and processing state |
| `series-memberships-v2` | Requester's own authorized memberships | Trusted membership workflow; clients cannot mint membership or elevated roles |
| `join-codes-v2` | Prefer backend resolution rather than listing codes | Trusted backend only |
| `commands-v2`, `series-routing-v2` | Only the minimum client reads actually used | Trusted backend only; prevent forged receipts and routing/cutover state |
| `suggestion-box` | Submitter only if the product requires it; otherwise admin | Authenticated bounded submissions with validated fields; no public reads |
| `courseAIUsage` | No client access | No client access; Admin SDK quota code only |
| Unrecognized collections/subcollections | Deny | Deny |

Avoid global admin claims for per-round permissions. Prefer the existing membership/participant model when it can provide trustworthy, inexpensive rule checks. Add a narrowly scoped UID access record only if existing documents cannot express the required grant. Do not create a new general authorization framework.

Firestore rules cannot hide selected fields inside an otherwise readable document. If discovery requires a public player summary, expose only that summary through a targeted endpoint or separate minimal record; do not expose the private account document. Query behavior also must match the policy: rules reject potentially unauthorized query results rather than filtering them. [Firestore query security](https://firebase.google.com/docs/firestore/security/rules-query), [field access and validation](https://firebase.google.com/docs/firestore/security/rules-fields)

## Implementation sequence

### 1. Establish the access inventory and recovery baseline

1. Re-fetch active releases in both projects and record their rule sources, IDs, and timestamps in the implementation evidence.
2. Inventory deployed databases and collections. The present inspection covers the default Firestore release, not every possible named database or Firebase service.
3. Trace client reads, queries, listeners, batched writes, and callable operations for V1 and V2. Include the current TestFlight build, alternate join/deep-link paths, Apple Watch behavior where applicable, and reconnect/offline synchronization.
4. Map each operation to a principal and permission already represented in the app. Separate host, commissioner, member, guest scorer, and spectator.
5. Inspect a minimal, appropriately handled sample of existing identity/ownership fields. Identify unmapped or inconsistent legacy records; do not grant all users access as a migration fallback.
6. Check existing backup/PITR availability and recovery procedures before any data migration. Rules-only deployment does not migrate or repair existing data.

### 2. Make guest access verifiable by the server

1. Reuse an existing Firebase session. If no session exists, establish anonymous authentication before protected guest lookup/join requests. Await successful sign-in before starting listeners. Do not replace a registered session or churn anonymous UIDs on repeated entry.
2. Preserve code/QR/deep-link entry. Resolve an invitation through a narrow authenticated callable where full document access before membership would otherwise be required. Return only the preview information needed for joining.
3. Validate the invitation and guest's allowed action on the server. A document ID alone is not proof of permission. Preserve legacy links through an explicit compatibility path rather than silently declaring all IDs to be invitations.
4. Atomically bind the authenticated UID to the permitted participant/member/spectator scope. Do not trust client-supplied `user_id`, `isHost`, commissioner roles, or local `ephemeralParticipantID` as proof of authority.
5. Handle an existing offline participant claim as an explicit operation. Decide whether a valid code alone permits the claim or whether host approval/additional proof is required. Prevent competing claims from overwriting each other.
6. Have rules consult the resulting trustworthy grant. Restrict who can create, change, or revoke it. The guest should be able to perform approved gameplay without creating an Apple/Google account.
7. Bound invitation guessing with appropriate callable throttling and failure responses that do not disclose full rosters. A per-UID limit alone does not stop abuse across freshly created anonymous identities.

Firestore rules cannot inspect an arbitrary invitation code from the UI unless the request/data model represents a verifiable condition. Do not solve the lookup problem by allowing all authenticated users to list rounds and series.

### 3. Align account and gameplay operations with the rules

- Prefer fetching the current private user document by Firebase UID. Check existing email-based account matching for legacy cross-provider records before switching it; migrate mismatches deliberately rather than making private email searches broadly readable.
- Enforce field allowlists, types, size/range limits, and immutable identity/ownership fields on create and update. In particular, reject client changes to membership roles and fields later trusted by Admin SDK callables.
- Express scoring permissions from the existing product rules. Some formats may intentionally let a scorer enter scores for a group/team; “only your own score document” is not automatically correct.
- Preserve permission differences between regular play, spectator access, editing completed rounds, and commissioner actions. Enforce these server-side as well as in the UI.
- Move derived results, command receipts, quota counters, and migration/routing mutations behind existing backend ownership where applicable. Review Admin SDK handlers individually because client rules do not constrain them.
- Keep any public configuration exception to exact documents and read operations. Replace the current unguarded share-code-length write with an appropriate trusted operation or strictly validated transition.
- Make permission failures observable and distinguish them from “not found.” In particular, audit `getUniqueShareCode` retries so denied lookup queries cannot cause repeated length bumps or endless retries.

### 4. Implement and test explicit rules

- Use explicit collection/subcollection matches and deny unmatched paths.
- Add only the helper functions needed for common authenticated UID, scoped membership, and role checks.
- Do not leave a recursive permissive match beside the new rules. A narrower deny cannot override a matching allow.
- Cover `get`, `list`, `create`, `update`, and `delete`; include transactions and batched writes that the app actually performs.
- Use the Firebase Emulator Suite with untrusted client contexts. Seed fixtures using a privileged test context, then exercise requests as signed-out, anonymous, registered, and authorized role-bearing users. An Admin SDK success is not a client-rules test. [Rules testing guidance](https://firebase.google.com/docs/firestore/security/test-rules-emulator)
- Update or replace `functions/test-course-ai-rules.py`, including its broad-access expectations and sandbox-only targeting. Add a repeatable rules-test command to the existing backend test workflow.

### 5. Roll out in an order that keeps the beta usable

1. Validate new handlers and rules with local fixtures before touching either live project.
2. Deploy the necessary backend support and compatible guest/auth client behavior to sandbox first.
3. Test a sandbox build with real guest, registered, host, commissioner, and spectator sessions.
4. Backfill only required authorization records through a reviewed, idempotent migration with dry-run output and a recovery plan. Do not grant permissions based on arbitrary client-authored roles without validating their provenance.
5. Deploy the sandbox rules and run both allowed and denied client checks. Check persisted sessions, revoked access, offline queued writes, and listeners after reconnection.
6. Coordinate an updated TestFlight build before restrictive production rules if the current build lacks the required grant or lookup flow. Use the existing minimum-version mechanism only after testing its bootstrap-read compatibility.
7. Deploy to production explicitly after sandbox verification. Confirm the active release source in **each** project; a successful sandbox deploy is not evidence of a production fix.
8. Monitor permission errors and broken join/scoring flows. Keep a tested restrictive recovery ruleset. Do not treat restoration of `allow ... if true` as a routine rollback; it would reopen the exposure.

For a future rules-only deployment, the intended CLI scope is `--only firestore:rules` with an explicit `--project hackers-compete-sandbox` or `--project hackers-compete`. Verify the installed CLI and authenticated account before running. These are planning notes, not commands executed during this documentation task.

## Required test matrix

| Scenario | Expected outcome |
| --- | --- |
| No Firebase token requests private documents or queries | Denied |
| Expired/invalid Firebase token | Denied |
| Anonymous UID with no grant requests unrelated round/series or roster | Denied |
| Anonymous guest follows a valid approved join flow | Receives only the allowed scoped access; gameplay works without Apple/Google sign-in |
| Guest claims a participant already controlled by someone else | Rejected or processed through an explicitly authorized handoff |
| Guest changes a local participant ID or submits another UID/role | Cannot gain that identity or permission |
| Guest requests unrelated participant scores or edits round structure | Denied unless an explicit scoring/host permission authorizes that exact action |
| Authorized scorer edits assigned team/group scores | Allowed according to the existing format's rules |
| Spectator reads permitted results and attempts a write | Read allowed; write denied |
| Registered user accesses another user's private document | Denied |
| User edits their own allowed fields or attempts to mint credits/roles | Allowed fields succeed; privilege changes fail |
| Client modifies membership, command receipt, processing state, or routing | Unauthorized mutations denied; approved callable path still works |
| Any client accesses `courseAIUsage`, including nested paths | All reads/writes denied |
| Unknown collection or uncovered nested subcollection | Denied |
| V1 and V2 dashboard, join, roster, score, and result queries | Authorized paths work without leaking other activity |
| Cold launch and legal/minimum-version checks | Work with the narrowly approved bootstrap policy |
| Relaunch, reconnect, sign-out, revoked membership, account upgrade | Identity/grant behavior is correct; no stale grant can authorize new server access |
| Atomic/batched write containing an unauthorized mutation | Rejected without partial permission bypass |

Also test Apple/Google account linking when a guest upgrades. Firebase supports linking credentials to an anonymous account, but the current provider path signs in directly. Decide whether to retain the guest UID by linking or transfer grants through a verified server operation when a registered account already exists. Never let clients claim arbitrary prior UIDs. [Anonymous account linking](https://firebase.google.com/docs/auth/ios/anonymous-auth)

## Historical exposure review

When remediation is scheduled, assess both projects without assuming a breach:

- Determine which data was actually stored during the exposed period, including user contact information, player data, and activity records. The model definitions show possible fields, not proof that every field is populated in either project.
- Check rule-release history, retained audit logs, enabled Data Access logging, usage/billing anomalies, and existing backups/exports. The production rule timestamp establishes this release's age; it does not establish the first date of exposure.
- Verify what request types and identities the available logs capture. Missing logs or no visible anomaly cannot prove no access occurred. Enabling logging later does not reconstruct past traffic. [Firestore audit logging](https://docs.cloud.google.com/firestore/native/docs/audit-logging), [Data Access log configuration](https://docs.cloud.google.com/logging/docs/audit/configure-data-access)
- Compare ownership/membership roles, totals, histories, and deleted/missing records against trustworthy backups or known beta activity. Treat client-writable timestamps and role fields as untrusted evidence.
- Handle any discovered sensitive data or incident evidence privately. Record confirmed findings separately from hypotheses.

No logs, records, or backup contents were inspected for this note. No conclusion about historical misuse is available.

## Related controls and boundaries

**Cloud Run / callable AI:** Public HTTP reachability and Firestore data authorization are separate controls. The earlier AI changelog reports sandbox rejection of missing and invalid Firebase tokens with HTTP 401. The local handler also rejects anonymous AI use. Those results were not rerun in this documentation task, and they do not validate Firestore rules. Preserve the existing AI authentication/quota boundary unless a separate product decision changes it.

**App Check:** Consider it as an additional abuse-control rollout after verifying support in TestFlight, production, and simulator/debug flows. It complements Firebase Authentication and per-document authorization; it does not replace either. Review request metrics before enforcement to avoid unexpectedly blocking beta clients. [Firebase App Check](https://firebase.google.com/docs/app-check)

**Other Firebase services:** Storage rules, IAM, API-key restrictions, and other databases were not audited. Track any findings separately rather than implying this Firestore plan secures every backend surface.

## Decisions needed before implementation

The owner has already settled that anonymous guest access must remain. Do not ask again whether to remove it. Remaining decisions should be resolved from existing product behavior first:

1. Which actions may guests perform: claim/create a participant, score for others, edit completed scores, join a series, and spectate?
2. Is possession of an invite sufficient to claim an offline participant, or is additional confirmation required?
3. How should guest access survive device changes or upgrades to an existing registered account, and when should grants expire or be revoked?
4. Which course/player discovery data is intentionally shared, and who may modify community course data or offline player records?
5. Which supported TestFlight versions need a compatibility window, and who signs off on the sandbox-to-production rollout?

Do not guess these business rules or introduce a permanent schema until the relevant existing behavior and data have been reviewed.

## Completion criteria

- [ ] Both projects have verified, version-controlled rules with no blanket client access.
- [ ] Anonymous guests retain the approved join and gameplay experiences.
- [ ] Every private/shared access is tied to ownership or a trustworthy scoped permission.
- [ ] Clients cannot grant themselves membership, elevate roles, forge backend state, or tamper with AI counters.
- [ ] Relevant V1/V2 queries, subcollections, callables, and field changes have positive and negative tests.
- [ ] Existing beta data and client versions have a tested migration/compatibility path.
- [ ] Sandbox and production active releases and client smoke tests are recorded independently.
- [ ] Historical review documents its findings and visibility limits without claiming that missing evidence proves safety.

## What was done for this note

Read-only inspection of local code and the deployed default Firestore rules; creation of this future-work document and its changelog entry. No app code, Firebase rules, deployment configuration, database data, authentication settings, or live infrastructure was changed.
