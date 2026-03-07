
# Hackers Golf Scoring Engine Architecture
## Comprehensive Game Template & Scoring System Specification
Version: 2.0

---

# Table of Contents

1. Overview
2. Design Goals
3. Core Architectural Concepts
4. Firestore Data Model
5. Round Structure
6. Segment Architecture
7. Segment Competition Sides
8. GameTemplate System
9. Scoring Engine Pipeline
10. ScoreEntry Model
11. Score Input Modes
12. Selection vs Reduction
13. Rank Selection Aggregation
14. Aggregation Scope
15. Aggregation Subject
16. Scoring Unit Generation
17. Template Examples
18. Complex Format Examples
19. Event‑Based Games
20. AI Generated Game Formats
21. Validation Rules
22. Builder UX Strategy
23. Debugging Strategy
24. Future Extensions

---

# 1. Overview

Hackers is designed to support **nearly any golf scoring format** including:

- stroke play
- match play
- stableford
- scramble
- best ball
- best N of M
- wolf
- bingo bango bongo
- skins
- custom golf trip games
- AI‑generated formats

The core idea is that **games are defined by templates**, not hardcoded formats.

Every scoring behavior is derived from:

```
ScoreEntry
+ GameTemplate
+ SegmentCompetitionSides
```

The scoring engine is **stateless and fully recomputable**.

---

# 2. Design Goals

The architecture must:

• support arbitrary golf formats  
• allow segments to redefine teams  
• support rotating partners  
• support side games  
• support AI generated formats  
• remain debuggable in Firestore  
• keep scoring deterministic  

---

# 3. Core Architectural Concepts

The system revolves around five core entities:

```
Round
Segment
GameTemplate
SegmentCompetitionSide
ScoreEntry
```

Each serves a specific role.

| Entity | Purpose |
|------|------|
Round | container for participants |
Segment | hole range with specific rules |
GameTemplate | defines scoring rules |
SegmentCompetitionSide | who competes |
ScoreEntry | canonical score input |

---

# 4. Firestore Data Model

```
rounds/{roundId}
    participants/{participantId}
    teams/{teamId}
    segments/{segmentId}
        competitionSides/{sideId}
        gameTemplates/{templateId}
        scoreEntries/{entryId}
```

Important rule:

**ScoreEntries are the only persisted scoring state.**

Everything else is derived.

---

# 5. Round Structure

```
Round
 ├ Participants
 ├ IdentityTeams
 └ Segments
```

Identity teams are persistent groups like:

```
Red Team
Blue Team
```

These are **not always the competitive sides**.

---

# 6. Segment Architecture

Segments represent a hole range.

Example:

```
Segment 1
holes 1‑6

Segment 2
holes 7‑12

Segment 3
holes 13‑18
```

Each segment may use different:

- teams
- templates
- scoring logic

---

# 7. Segment Competition Sides

Segments explicitly define **who competes**.

Example:

Segment 1:

```
R1 + B1
R2 + B2
```

Segment 2:

```
R1 + B2
R2 + B1
```

Segment 3:

```
Red Team
Blue Team
```

Model:

```
SegmentCompetitionSide
{
    id
    participantIds[]
    name
}
```

This prevents complex inference logic.

---

# 8. GameTemplate System

GameTemplates define scoring rules.

```
GameTemplate
{
    id
    name
    inputMode
    subject
    scoreSource
    aggregation
}
```

Templates are reusable across segments.

---

# 9. Scoring Engine Pipeline

Scoring follows a deterministic pipeline:

```
ScoreEntry
    ↓
player scores
    ↓
group by subject
    ↓
selection
    ↓
reduction
    ↓
leaderboard
```

This pipeline supports all formats.

---

# 10. ScoreEntry Model

ScoreEntry stores **only user input**.

Example Swift model:

```swift
struct ScoreEntry {

    var id: String

    var holeNumber: Int
    var segmentID: String
    var gameTemplateID: String

    var scoringUnitID: String
    var participantIDs: [String]

    var strokes: Int?

    var eventValue: String?

    var points: Double?

    var rawEntry: [String: AnyCodable]?

    var outcome: HoleOutcome

    var entryID: String

    var createdAt: Time
    var lastUpdatedAt: Time

    var parentID: String
    var schema: Int
}
```

---

# 11. Score Input Modes

Templates define how input works.

### Stroke Mode

```
strokes entered
points computed
```

### Event Mode

```
eventValue entered
points assigned via template
```

Example:

```
greenie = 5
```

### Points Mode

User directly enters points.

Used for betting or manual games.

---

# 12. Selection vs Reduction

Scoring aggregation is separated into two operations.

### Selection

Choose which scores count.

Example:

```
best 2
worst 1
middle 2
```

### Reduction

Combine scores.

Example:

```
sum
difference
points
```

---

# 13. Rank Selection Aggregation

Rank selection replaces:

- best ball
- worst ball
- best 2 of 4
- best + worst

Example:

```
includeRanks = [1,2]
```

Or:

```
excludeRanks = [1]
```

Scores are sorted then filtered.

---

# 14. Aggregation Scope

Defines when aggregation happens.

```
perHole
perRound
```

Example:

Best 2 of 4 per hole:

```
scope = perHole
includeRanks = [1,2]
```

Best 2 of 4 for the round:

```
scope = perRound
includeRanks = [1,2]
```

---

# 15. Aggregation Subject

Defines **who is being ranked**.

Options:

```
participant
team
competitionSide
custom
```

Example:

```
subject = team
```

---

# 16. Scoring Unit Generation

Scoring units represent entities being scored.

Examples:

Stroke play:

```
unit = participant
```

Best Ball:

```
unit = team
```

Scramble:

```
unit = team
shared score
```

---

# 17. Template Examples

## Stroke Play

```
subject: participant
input: strokes
aggregation: sumAll
scope: perRound
```

## Stableford

```
subject: participant
input: strokes
pointsMap
aggregation: sum
```

## Best Ball

```
subject: team
includeRanks: [1]
scope: perHole
```

## Best 2 of 4

```
subject: team
includeRanks: [1,2]
scope: perHole
```

## Scramble

```
subject: team
scoreSource: scoringUnit
aggregation: sum
```

---

# 18. Complex Format Examples

## Rotating Partners

Segment 1:

```
A+B vs C+D
```

Segment 2:

```
A+C vs B+D
```

Segment 3:

```
A+D vs B+C
```

---

# 19. Event‑Based Games

Example: Greenies

Template:

```
inputMode: event
events:
    greenie: 5
```

ScoreEntry:

```
eventValue = greenie
```

Engine assigns points.

---

# 20. AI Generated Game Formats

Users may describe formats:

Example:

```
"Create a game where we drop the best score each hole."
```

AI outputs template JSON:

```
aggregation:
    excludeRanks: [1]
    scope: perHole
```

Template is validated before saving.

---

# 21. Validation Rules

Example rules:

| Rule | Description |
|----|----|
rankSelection requires ranks |
pointsMode requires points input |
eventMode requires event map |
includeRanks XOR excludeRanks |

---

# 22. Builder UX Strategy

Game creation UI asks four questions:

1. Who is scored?
2. What input is entered?
3. How are scores selected?
4. How are scores reduced?

A rule sentence is generated:

Example:

```
Teams enter strokes.
The best 2 scores per hole count.
Lowest team score wins.
```

---

# 23. Debugging Strategy

Because ScoreEntry is canonical:

Entire leaderboards can be recomputed.

Debugging pipeline:

```
load ScoreEntries
load GameTemplate
recompute results
```

No hidden state exists.

---

# 24. Future Extensions

Architecture supports:

• creator game marketplace  
• shared format library  
• AI generated games  
• tournament support  
• live betting formats  

The system effectively becomes a **golf game DSL (domain specific language)**.

