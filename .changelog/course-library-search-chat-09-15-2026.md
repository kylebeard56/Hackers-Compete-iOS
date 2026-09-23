# Shared course library, search, and chat

Date: 09-15-2026

## Scope Boundary

- Extend the existing Cloud Firestore course library, word-based search, provider fallback, recent-course recovery, and AI conversation.
- Preserve existing course/round IDs and historical snapshots. No production migration, provider replacement, or OCR extraction redesign.

## Design Decisions

- Persist all returned summaries; fetch full scorecards only when needed. Never replace a complete or deliberately edited scorecard with a summary.
- Existing document IDs remain stable Hackers identifiers; additive source references record provider identity without changing old round contracts.
- Distinguish failed cloud reads from successful empty searches. Keep persistence failures invisible to users and visible in telemetry.
- Use explicit “Search more courses” when local matches are insufficient. Preserve identity through chat confirmation and location replies.

## Deviations

None yet.

## Tradeoffs

- Existing records without word indexes retain prefix-search compatibility; a production backfill requires separate data inspection.
- Production course inspection is currently blocked by account permissions/reauthentication.

## Open Questions

- Account-specific duplicate verification and deployed AI smoke tests require production access.
