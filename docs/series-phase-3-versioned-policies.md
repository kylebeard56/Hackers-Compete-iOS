# Series Phase 3: Versioned Policies And Guardrails

## Boundary

Phase 3 defines which round contracts are compatible with a Series standings policy. It does not change result ingestion, point aggregation, leaderboard sorting, or tiebreakers. Those remain Phase 4 and Phase 5 work.

## Model

- `SeriesRoundDefaults` is the convenience input for future rounds. It is backed by the existing `SeriesSettings` keys, so legacy clients and documents keep the same wire format.
- `SeriesStandingsPolicy` contains independently evaluated team and individual rules.
- `SeriesPolicyRevision` is an immutable policy snapshot with a sequence and SHA-256 fingerprint.
- `SeriesRoundPolicyBinding` stores the full revision snapshot plus resolved substitute-scoring behavior. Historical rounds never need to consult a mutable policy revision.
- A round without `policy_binding` resolves to `.legacySnapshot` and retains historical classification and standings behavior.

## Resolution

New rounds bind to `settings.standings_policy_revision` only when one has been explicitly installed. Existing leagues therefore remain unbound until a later policy-authoring flow opts them in.

Each standings rule is classified as:

- `eligible`: the round contract matches the rule.
- `normalized`: the mismatch is covered by an explicit normalization policy, currently 9-hole to 18-hole.
- `excluded`: the round is valid to play but does not satisfy that standings rule.
- `invalid`: required data or policy integrity is missing, duplicated, or malformed.

Compatibility inputs are track, template, gross/net basis, hole count, stroke/match family, team aggregation mode/count/scope, and substitute behavior. Fingerprints canonicalize rule and constraint ordering before encoding.

## Lifecycle Rails

Planned and lobby rounds may change their score contract. Live, completed, and canceled rounds may change descriptive metadata, but changes to course, format, score basis, aggregation, matchup structure, handicap scoring behavior, scoring profiles, policy binding, or authored pair/group plans are rejected before local or Firebase persistence.

Round creation performs policy preflight. An invalid policy contract blocks creation before a linked round is written. Eligible, normalized, and excluded contracts remain playable; standings filtering is intentionally deferred until the versioned result and standings pipelines exist.

## Compatibility

The new fields are additive and optional:

- `settings.standings_policy_revision`
- `series_round.policy_binding`

No migration runs automatically. Existing settings keys remain authoritative, nil policy fields are omitted when encoding, and legacy fixtures continue through `.legacySnapshot`.

## Next Phases

Phase 4 should attach the resolved policy fingerprint and compatibility decision to canonical round results. Phase 5 can then aggregate only eligible/normalized results and add policy-defined tiebreakers such as lowest gross or net scoring average without re-reading mutable round configuration.
