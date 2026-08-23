# Firebase Round Architecture & Game Format Scaling Guide

A comprehensive document of the Hackers FirebaseService setup, Round model structure, collections/subcollections, game format and configuration—and where to scale beyond stroke play.

---

## 1. FirebaseService Overview

### Core Service

- **Location:** `Hackers/Core/Firebase/Core/FirebaseService.swift`
- **Type:** `final actor FirebaseService: Sendable, Loggable`
- **Pattern:** Singleton via `FirebaseService.shared`
- **Collections enum:** `Collections` defines top-level Firestore collections

### Top-Level Collections

| Collection | Purpose |
|------------|---------|
| `configuration` | App config (terms version, policy version, minimum app version) |
| `courses` | Golf course data (API/OCR) |
| `players` | Player profiles |
| `rounds` | Round documents (root of round hierarchy) |
| `suggestion-box` | User feedback |
| `users` | User accounts |

### Round-Specific API

Round CRUD and subcollection access live in `Hackers/Core/Firebase/Collections/Firebase+Round.swift`:

- `getRoundByShareCode(_:)` / `getRoundByID(_:)` — fetch round by share code or ID
- `fetchRounds(playerID:)` — rounds where a player participates
- `markPlayerComplete(roundID:completedPlayer:)` — append to `completed_players` array
- `getParticipant(by:for:)` / `getParticipants(for:)` — participants subcollection
- `getScore(by:for:)` / `getScores(for:)` — scores subcollection
- `getTeam(by:for:)` / `getTeams(for:)` — teams subcollection
- `getTeeGroup(by:for:)` / `getTeeGroups(for:)` — tee-groups subcollection
- `getSegment(by:for:)` / `getSegments(for:)` — segments subcollection

---

## 2. Round Model & Firestore Structure

### Root Document Path

```
rounds/{roundId}
```

### Round Document Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Document ID |
| `share_code` | String | Join code (e.g. `ABC123`) |
| `created_by` | String | User ID of creator |
| `status` | RoundStatus | lobby, live, paused, complete, archived |
| `primary_format` | GameFormat | Primary game format |
| `courses` | [CourseSegment] | Course metadata and hole sequence |
| `players` | [String] | Player IDs in round |
| `created_at` | Time | Creation timestamp |
| `last_updated_at` | Time | Last update timestamp |
| `schema` | Int | Schema version (1) |

### RoundStatus

| Status | Meaning |
|--------|---------|
| `lobby` | Pre-round setup |
| `live` | Active scoring |
| `paused` | Config changes, scoring locked |
| `complete` | Finished, immutable |
| `archived` | Soft-deleted, hidden from queries |

---

## 3. Subcollections

All subcollections live under `rounds/{roundId}/`:

```
rounds/{roundId}/
├── participants/{participantId}
├── teams/{teamId}
├── tee-groups/{groupId}
├── scores/{scoreId}
└── segments/{segmentId}
```

### 3.1 `participants` — RoundParticipant

**Path:** `rounds/{roundId}/participants/{participantId}`

Round-local snapshot of each player.

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | Participant ID |
| `user_id` | String? | Auth user ID |
| `player_id` | String? | Player profile ID |
| `name` | Name | Display name |
| `tee_box_id` | String | Tee used |
| `original_handicap` | Int | Input handicap |
| `adjusted_handicap` | Int | Course/slope adjusted |
| `team_id` | String? | Team assignment |
| `group_id` | String? | Tee group assignment |
| `tee_order` | Int? | Order in group |
| `is_host` | Bool | Host flag |

**Why it exists:** Denormalized snapshot so the round is self-contained and doesn't need live player lookups during scoring.

---

### 3.2 `teams` — RoundTeam

**Path:** `rounds/{roundId}/teams/{teamId}`

Optional team metadata for colors and grouping.

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | Team ID |
| `name` | String | e.g. "Red Team", "Blue Team" |
| `color` | String | TeamColor raw value |
| `index` | Int | Order |

**Why it exists:** Supports team-based formats and leaderboard views. Used when `configuration.primaryFormat.configuration.requiresTeams == true`.

---

### 3.3 `tee-groups` — TeeTimeGroup

**Path:** `rounds/{roundId}/tee-groups/{groupId}`

Tee sheet / shotgun groupings.

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | Group ID |
| `index` | Int | Group order |
| `tee_time` | String? | ISO8601 tee time |
| `starting_hole` | Int | First hole |
| `last_completed_hole` | Int? | Progress |

**Why it exists:** Organizes players into groups for tee times and "group" leaderboard mode. Participants reference via `group_id`.

---

### 3.4 `scores` — ScoreEntry

**Path:** `rounds/{roundId}/scores/{scoreId}`

Flexible score storage; can represent individual or team scores.

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | Deterministic: `h{hole}_s{segment}_u{unit}` |
| `hole_number` | Int | Hole |
| `segment_id` | String | RoundSegment ID |
| `group_id` | String | Tee group (for context) |
| `scoring_unit_id` | String | ScoringUnit ID (participant or team) |
| `participant_ids` | [String] | Denormalized participant IDs |
| `strokes` | Int? | Gross strokes (nil = unscored) |
| `value` | String? | Non-stroke value (e.g. match play) |
| `picked_up` | Bool | Skipped hole |
| `entry_id` | String | Who entered the score |
| `created_at` / `last_updated_at` | Time | Timestamps |

**ID format:** `ScoreEntry.makeID(hole:segment:scoringUnit)` → `h7_sseg1_uparticipant_1`

**Why it exists:** Central score store. `scoring_unit_id` and `participant_ids` allow both individual and team scoring; `value` supports non-stroke formats (e.g. match play points).

---

### 3.5 `segments` — RoundSegment

**Path:** `rounds/{roundId}/segments/{segmentId}`

Defines format and scoring units for a hole range (e.g. Nassau, 6-6-6).

| Field | Type | Purpose |
|-------|------|---------|
| `id` | String | Segment ID |
| `round_id` | String | Round ID |
| `hole_range` | HoleRange | Holes in segment |
| `game_format` | GameFormat | Format for this segment |
| `scoring_units` | [ScoringUnit] | Atomic scoring subjects |
| `created_at` / `last_updated_at` | Time | Timestamps |

**Why it exists:** Supports multi-format rounds (e.g. front 9 vs back 9, Nassau) and per-segment format overrides.

---

## 4. Game Format & Configuration

### 4.1 RoundConfiguration

**Location:** `Round.swift`

```swift
struct RoundConfiguration: Hashable, Codable {
    var primaryFormat: GameFormat   // Primary format (or per-segment override)
    var courses: [CourseSegment]    // Course metadata and hole sequence
}
```

- `primaryFormat` is the default; segments can override.
- `useHandicaps` is derived from `primaryFormat.configuration.basis == .net`.

---

### 4.2 GameFormat

**Location:** `Hackers/Shared/Models/Round/Game/GameFormat.swift`

```swift
struct GameFormat: Hashable, Codable {
    var type: GameFormatType = .strokePlay
    var configuration: GameConfiguration = .init()
}
```

**GameFormatType (current):**

| Type | Display | Summary |
|------|---------|---------|
| `stroke_play` | Stroke Play | Lowest total strokes wins |
| `match_play` | Match Play | Win holes, not strokes |

---

### 4.3 GameConfiguration

**Location:** `Hackers/Shared/Models/Round/Game/GameConfiguration.swift`

| Field | Type | Purpose |
|-------|------|---------|
| `method` | ScoringMethod | individual vs aggregate |
| `aggregation` | Aggregation? | How team scores are computed |
| `basis` | ScoreBasis | gross vs net |
| `handicap` | HandicapConfiguration | Percentage, team combined, position % |
| `requires_teams` | Bool | Teams required |
| `tee_group_only` | Bool | TODO: remove |
| `min_number_players` | Int? | Min players |
| `max_number_players` | Int? | Max players |
| `points_per_hole` | Int? | Match play only |
| `tie_policy` | TiePolicy? | half, pushover, carryover |
| `max_score_over_par` | MaxScoreOverPar | Cap per hole (bogey, double, triple, quad, etc.) |

**ScoringMethod:**

- `individual` — one participant per scoring unit
- `aggregate` — team aggregate (sum or best-N)

**Aggregation (when method == aggregate):**

- `mode`: `sumAll` or `countBest`
- `scope`: `perHole` or `perRound`
- `best_n`: Int? (for countBest)

---

### 4.4 Aggregation Model

**Location:** `Hackers/Shared/Models/Round/Game/Aggregation.swift`

```swift
struct Aggregation: Codable, Hashable {
    var mode: AggregationMode = .sumAll   // sumAll | countBest
    var scope: AggregationScope           // perHole | perRound
    var bestN: Int?                      // For countBest
}
```

**AggregationMode:**

- `sumAll` — sum of all member scores
- `countBest` — use best N scores (e.g. best 2 of 4)

**AggregationScope:**

- `perHole` — aggregate per hole, then sum
- `perRound` — aggregate total scores per round

---

### 4.5 ScoringUnit (embedded in RoundSegment)

**Location:** `Round+Scoring.swift`

```swift
struct ScoringUnit: Hashable, Codable, Identifiable {
    var id: String
    var owner: ScoringOwner           // participant | team
    var ownerIDs: [String]           // 1+ player/team IDs
    var scoringMethod: ScoringMethod  // individual | aggregate
    var aggregation: Aggregation?
    var handicapAdjustments: [String: Double]?
}
```

**ScoringOwner:** `participant` | `team`

**Current behavior:** Stroke play uses one ScoringUnit per participant (`owner: .participant`, `ownerIDs: [participant.id]`). Team formats would use `owner: .team` and `aggregation` to define how team scores are computed.

---

## 5. Current Implementation Gaps

### 5.1 Scoring Unit Population

- Round creation (`CourseSelectionViewModel.createRoundLobby`) creates a segment with `scoringUnits: []`.
- ScoringUnits are only populated in mocks and `CompleteRoundSheet.segmentForParticipants`.
- Live scoring assumes `scoringUnitID == participant.id` (see `LiveRoundViewModel.setScore`).

**Gap:** No explicit creation of ScoringUnits when players join or when the round goes live.

---

### 5.2 Leaderboard Modes

- **Individual:** Sum of strokes per participant.
- **Team:** Groups by team, shows individuals; `bestScoreToPar` is the best individual in the team, not an aggregated team score.
- **Tee Group:** Same pattern for groups.

**Gap:** No true team aggregate (e.g. best 2 of 4, sum of best ball) in the leaderboard.

---

### 5.3 Game Format Support

- Only `strokePlay` and `matchPlay` are implemented.
- Match play has config (`pointsPerHole`, `tiePolicy`) but no scoring UI.
- `teeGroupOnly` exists but is marked for removal.

---

## 6. Scaling Beyond Stroke Play

### 6.1 Individual vs Team

**Already present:**

- `GameConfiguration.method`: `.individual` | `.aggregate`
- `GameConfiguration.requiresTeams`
- `ScoringUnit.owner`: `.participant` | `.team`
- `ScoringUnit.aggregation`

**To add:**

1. When activating a team round, create ScoringUnits with `owner: .team` and `aggregation` from config.
2. Map ScoreEntry to team via `scoringUnitID` = team ID for team formats.
3. For captain's choice / scramble: one ScoreEntry per hole per team; `participant_ids` = all team members.

---

### 6.2 Aggregation: Best N, Best/Worst, Vegas

**AggregationMode:**

- `sumAll` — already supported.
- `countBest` — add `bestN` (e.g. best 2 of 4).

**New modes to consider:**

- `bestSingle` — best 1 score (best ball).
- `worstSingle` — worst score (e.g. wolf).
- `vegas` — score differentials between players (e.g. A vs B: low score wins points based on spread).

**AggregationScope:**

- `perHole` — already supported (best N per hole, then sum).
- `perRound` — already supported (best N total scores).

**Implementation:** Extend `AggregationMode` and add computation in `LiveRoundViewModel` (or a dedicated scoring engine) for `scoreToPar` when `method == .aggregate`.

---

### 6.3 Match Play

**Already present:**

- `GameFormatType.matchPlay`
- `GameConfiguration.pointsPerHole`, `tiePolicy`
- `ScoreEntry.value` for non-stroke values

**To add:**

1. Match play scoring UI: hole winner, halved, points.
2. Store result in `ScoreEntry.value` (e.g. `"1"`, `"0.5"`, `"0"`) or a structured format.
3. Leaderboard: points per match, not strokes.
4. Optional: match pairing model (who plays whom).

---

### 6.4 Shared Scoring (Captain's Choice, Scramble)

**Concept:** One score per hole per group/team, not per player.

**Model changes:**

1. **ScoringUnit:** `owner: .team`, `ownerIDs: [teamId]`, `scoringMethod: .aggregate`.
2. **ScoreEntry:** One per (hole, segment, team); `scoringUnitID` = team ID; `participant_ids` = all team members.
3. **Scoring UI:** Single score input per hole for the team.

**New config flag:** e.g. `sharedScoring: Bool` or `scoringGranularity: .perPlayer | .perTeam`.

---

### 6.5 Vegas Format

**Concept:** Points based on stroke differential between players (e.g. A 4, B 6 → A gets 2 points).

**Model changes:**

1. New `GameFormatType.vegas` (or variant of stroke play with Vegas config).
2. `ScoreEntry` stays per-player; Vegas points computed from stroke differentials.
3. New computed field or separate structure for Vegas points per hole.
4. Leaderboard shows Vegas points instead of strokes.

---

### 6.6 Nassau / 6-6-6 (Multi-Segment)

**Already supported:**

- `RoundSegment.holeRange` — front 9, back 9, custom.
- `RoundSegment.gameFormat` — per-segment format.
- Multiple segments per round.

**To add:**

1. Segment creation for front 9, back 9, overall.
2. Per-segment ScoringUnits and GameFormat.
3. Leaderboard that shows front, back, overall separately.

---

## 7. Recommended Extension Points

### 7.1 GameFormatType

```swift
enum GameFormatType: String, CaseIterable, Codable {
    case strokePlay = "stroke_play"
    case matchPlay = "match_play"
    case bestBall = "best_ball"        // Best 1 of N per hole
    case scramble = "scramble"         // Captain's choice, shared score
    case vegas = "vegas"               // Stroke differential points
    case wolf = "wolf"                 // Rotating wolf, worst score
    // ...
}
```

### 7.2 AggregationMode

```swift
enum AggregationMode: String, Codable {
    case sumAll = "sum_all"
    case countBest = "count_best_n"
    case bestSingle = "best_single"    // Best 1 per hole/round
    case worstSingle = "worst_single"
    case vegasDifferential = "vegas_differential"
}
```

### 7.3 Scoring Granularity

```swift
enum ScoringGranularity: String, Codable {
    case perPlayer = "per_player"      // One score per player per hole
    case perTeam = "per_team"          // One score per team per hole (scramble, captain's choice)
}
```

### 7.4 ScoreEntry Enhancements

- `value` already supports non-stroke (match play points, Vegas points).
- Optional: `points: Int?` for numeric points.
- Optional: `match_result: String?` for match play (e.g. "won", "halved", "lost").

---

## 8. Data Flow Summary

```
Round (root)
  └── RoundConfiguration.primaryFormat (GameFormat)
        └── GameFormat.type (stroke_play | match_play)
        └── GameFormat.configuration (GameConfiguration)
              └── method, aggregation, basis, requiresTeams, etc.

RoundSegment (per hole range)
  └── gameFormat (override for Nassau, etc.)
  └── scoringUnits: [ScoringUnit]
        └── owner: participant | team
        └── ownerIDs, aggregation, scoringMethod

ScoreEntry (per hole, per scoring unit)
  └── scoringUnitID → ScoringUnit
  └── participantIDs (denormalized)
  └── strokes | value (flexible)
```

---

## 9. File Reference

| File | Purpose |
|------|---------|
| `FirebaseService.swift` | Core service, Collections enum |
| `Firebase+Round.swift` | Round CRUD, subcollection access |
| `Firebase+API.swift` | FirebaseSubcollectable, generic CRUD |
| `Round.swift` | Round, RoundConfiguration, RoundSubcollection |
| `Round+Participant.swift` | RoundParticipant |
| `Round+Teams.swift` | RoundTeam, TeamColor |
| `Round+TeeGroup.swift` | TeeTimeGroup |
| `Round+Scoring.swift` | ScoreEntry, ScoringUnit, ScoringOwner, ScoringMethod |
| `Round+Segment.swift` | RoundSegment |
| `GameFormat.swift` | GameFormat, GameFormatType |
| `GameConfiguration.swift` | GameConfiguration, HandicapConfiguration, MaxScoreOverPar, TiePolicy |
| `Aggregation.swift` | Aggregation, AggregationMode, AggregationScope |
| `Round+Course.swift` | CourseSegment, CourseInfo |
| `RoundSnapshot.swift` | In-memory snapshot of round + subcollections |
| `RoundSession.swift` | Session, listeners, fetch |
| `LiveRoundViewModel.swift` | Scoring, leaderboard, scoreToPar |

---

*Document generated from codebase analysis. Last updated: March 2025.*
