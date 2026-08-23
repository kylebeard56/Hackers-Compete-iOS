# Series Phase 2: Configuration Fidelity

## Authority Contract

- `SeriesRoundDraft` is the single editing model for new and existing Series rounds.
- `SeriesRound` owns round configuration from planning through the linked lobby.
- League defaults seed newly created rounds. Later default changes do not modify existing rounds.
- A linked lobby may change independently, but those changes do not silently alter Series configuration.
- Lobby differences are surfaced as `SeriesRoundConfigurationDivergence` and require a commissioner to choose:
  - **Adopt lobby**: copy linked lobby configuration into the Series round.
  - **Reset lobby**: push the Series round configuration back into the linked lobby.

## Persistence Path

```text
New/Edit UI
  -> SeriesRoundDraft
  -> validated SeriesRoundDraftPersistenceValues
  -> SeriesRound
  -> linked Round mapping
  -> reload
  -> SeriesRoundDraft
```

Draft persistence starts from the source `SeriesRoundConfiguration` and replaces only fields represented by the editor. This preserves legacy, hidden, and future fields during an untouched edit.

Displayed fallback values do not automatically become explicit overrides. This applies to league fallback courses and template-provided shared-score handicap allowances.

## Validation

- Shared-score allowances must be comma-separated values from 0 through 100.
- Counted team scoring must include at least one score.
- Course-handicap entry falls back to stroke entry when course handicap data is unavailable.
- Handicap normalization is constrained to field or matchup scope.
- Member ID collections are normalized and deduplicated before persistence.

## Backward Compatibility

- Existing `SeriesRound` and `SeriesRoundConfiguration` Codable defaults remain unchanged.
- No Firestore migration or schema version change is required.
- The legacy `allowLobbyBackPropagation` field still decodes, but automatic lobby-to-Series configuration adoption is disabled.
- Existing linked live and completed rounds retain status and result ingestion behavior.

## Regression Gate

- Field-by-field draft persistence and JSON reload tests.
- Full round payload create/reload/edit test.
- Untouched hidden-field, fallback-course, and inherited-allowance preservation tests.
- Invalid allowance and note-clearing tests.
- Existing-round versus future-default max-score test.
- Linked lobby divergence and adoption mapping tests.
- Phase 0, Phase 1, Series Codable, creation mapping, and sync suites.

## Manual Sandbox Check

1. Create a planned round and set format, team scoring, matchup mode, handicap options, course, profiles, and notes.
2. Reopen the round and confirm every selection is restored.
3. Clear the notes, save, and confirm they remain cleared after reopening.
4. Duplicate a round with no course override after changing the league default course; confirm the copy still has no explicit override.
5. Create a linked lobby, change one format or handicap setting in the lobby, and return to the Series.
6. Confirm the round shows **Setup differs** and the sync sheet lists the differing categories.
7. Exercise **Adopt lobby** in Sandbox and confirm the Series edit UI reflects the lobby choice.
8. Create another divergence, exercise **Reset lobby**, and confirm the linked lobby returns to the Series choice.

