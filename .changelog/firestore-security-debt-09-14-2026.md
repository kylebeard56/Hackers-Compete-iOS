# Firestore Security Debt Documentation

Date: 09-14-2026

## Scope Boundary

- Changed: Added `.techdebt/firestore-access-control-09-14-2026.md` with verified rule evidence, repository constraints, a future remediation sequence, test matrix, and rollout/recovery guidance.
- Not touched: Application code, Firestore rules, Firebase deployment configuration, data, authentication settings, and live infrastructure. Existing working-tree changes belong to earlier work.

## Design Decisions

- Follow the owner's explicit documentation-only direction after read-only investigation.
- Preserve crucial guest access through Firebase anonymous authentication; removing guests or requiring Apple/Google sign-in is not the proposed fix.
- Distinguish authenticated identity from round/series authorization, including the current local-only guest participant claim.
- Record the approximately 40-person trusted TestFlight beta context and the limits of that distribution boundary.

## Deviations

None.

## Tradeoffs

- Remediation remains deferred. The note records a proposed policy and unresolved gameplay decisions rather than inventing a deployable authorization schema.

## Open Questions

- See the debt note for scoped guest permissions, invite/participant claims, account upgrades, community data access, and rollout compatibility.
- Historical misuse is unassessed; no document contents, audit logs, or backups were reviewed.
