# Dashboard Home Screen Redesign — Implementation Changelog

This document summarizes all changes made to implement the Dashboard Home Screen Redesign plan. Use it for code review and reference.

---

## Table of Contents

1. [New Files Created](#1-new-files-created)
2. [Modified Files](#2-modified-files)
3. [Removed / Unused](#3-removed--unused)

---

## 1. New Files Created

### 1.1 `Hackers/Shared/Models/Player/PlayerHistoryEntry.swift`

**Purpose:** Denormalized history of players this player has played rounds with. Supports per-round data for Recent (by `lastPlayedAt`) and Suggested (top in last 90 days) sorting.

```swift
//
//  PlayerHistoryEntry.swift
//  Hackers
//
//  Denormalized history of players this player has played rounds with.
//

import Foundation

// MARK: - RoundPlayedRef

struct RoundPlayedRef: Hashable, Codable {
    var roundID: String
    var playedAt: Time

    enum CodingKeys: String, CodingKey {
        case roundID = "round_id"
        case playedAt = "played_at"
    }

    init(roundID: String = "", playedAt: Time = .init()) {
        self.roundID = roundID
        self.playedAt = playedAt
    }
}

// MARK: - PlayerHistoryEntry

struct PlayerHistoryEntry: Hashable, Codable {
    var playerID: String
    var name: Name
    var rounds: [RoundPlayedRef]

    enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case name
        case rounds
    }

    init(playerID: String = "", name: Name = .init(), rounds: [RoundPlayedRef] = []) {
        self.playerID = playerID
        self.name = name
        self.rounds = rounds
    }

    var roundsPlayed: Int { rounds.count }
    var lastPlayedAt: Time? { rounds.map(\.playedAt).max(by: { $0.unix < $1.unix }) }
}
```

**Notes:**
- Uses snake_case CodingKeys (`round_id`, `played_at`) for Firestore
- `Time` from `Hackers/Legacy/Models/Time.swift` for indexing
- Per-round data enables 90-day frequency filtering for AddPlayerView Suggested section

---

### 1.2 `Hackers/Shared/Models/Player/CourseHistoryEntry.swift`

**Purpose:** Denormalized history of courses this player has played. Includes `CourseIDType` enum to abstract API vs manual course sources.

```swift
//
//  CourseHistoryEntry.swift
//  Hackers
//
//  Denormalized history of courses this player has played.
//

import Foundation

// MARK: - CourseIDType

enum CourseIDType: String, Codable {
    case courseAPI = "course_api"
    case manual = "manual"
}

// MARK: - CourseHistoryEntry

struct CourseHistoryEntry: Hashable, Codable {
    var courseID: String
    var courseIDType: CourseIDType
    var name: String
    var roundsPlayed: Int
    var lastPlayedAt: Time

    enum CodingKeys: String, CodingKey {
        case courseID = "course_id"
        case courseIDType = "course_id_type"
        case name
        case roundsPlayed = "rounds_played"
        case lastPlayedAt = "played_at"
    }

    init(
        courseID: String = "",
        courseIDType: CourseIDType = .courseAPI,
        name: String = "",
        roundsPlayed: Int = 0,
        lastPlayedAt: Time = .init()
    ) {
        self.courseID = courseID
        self.courseIDType = courseIDType
        self.name = name
        self.roundsPlayed = roundsPlayed
        self.lastPlayedAt = lastPlayedAt
    }

    var compositeKey: String { "\(courseIDType.rawValue):\(courseID)" }
}
```

**Notes:**
- `compositeKey` used for ForEach `id` and Firestore dictionary key
- `.manual` reserved for future user-created courses

---

### 1.3 `Hackers/Features/Dashboard/DashboardPlayerRow.swift`

**Purpose:** Player row for Recent/Top players section. Glass tile styled like `PlayerScoringRow`.

```swift
//
//  DashboardPlayerRow.swift
//  Hackers
//
//  Player row for Recent/Top players section. Styled like PlayerScoringRow.
//

import SwiftUI

struct DashboardPlayerRow: View {
    let entry: PlayerHistoryEntry
    let palette: DesignPalette

    private var subtitle: String {
        let count = entry.roundsPlayed
        let countStr = count == 1 ? "1 round" : "\(count) rounds"
        if let last = entry.lastPlayedAt {
            let date = Date(timeIntervalSince1970: last.unix)
            let rel = date.relativeTimeAgo
            return "\(countStr) together, last \(rel)"
        }
        return "\(countStr) together"
    }

    var body: some View {
        HStack(spacing: 12) {
            PlayerAvatarView(
                initials: entry.name.initials,
                size: 44,
                fillColor: .accentGreen.opacity(0.6),
                glassTint: .neutral6
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name.fullName)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Text(subtitle)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .glassCardEffect()
    }
}
```

---

### 1.4 `Hackers/Features/Dashboard/DashboardCourseRow.swift`

**Purpose:** Course row for Recent/Top courses section with "Play again" chip. Top mode shows `#1`, `#2` rank badge.

```swift
//
//  DashboardCourseRow.swift
//  Hackers
//
//  Course row for Recent/Top courses section with "Play again" chip.
//

import SwiftUI

struct DashboardCourseRow: View {
    let entry: CourseHistoryEntry
    let palette: DesignPalette
    var rank: Int? = nil
    var onPlayAgain: () -> Void

    private var subtitle: String {
        if let rank {
            return "\(entry.roundsPlayed) rounds"
        }
        let date = Date(timeIntervalSince1970: entry.lastPlayedAt.unix)
        return date.relativeTimeAgo
    }

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                rankBadge(rank)
            } else {
                Icon(name: "f3c5", size: 24, weight: .regular)
                    .foregroundStyle(Color.accentGreen)
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                Text(subtitle)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.fire(.light)
                onPlayAgain()
            } label: {
                Text("Play again")
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentGreen)
                    .cornerRadius(radius: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassCardEffect()
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text("#\(rank)")
            .fontStyle(kFontName, size: 17, weight: .bold)
            .foregroundStyle(palette.foregroundColor)
            .frame(width: 44, height: 44)
            .background(Color.accentGreen.opacity(0.2))
            .clipShape(Circle())
    }
}
```

---

### 1.5 `Hackers/Features/Dashboard/DashboardHomeViewModel.swift`

**Purpose:** Loads `playerHistory` and `courseHistory` from the primary player for home display.

```swift
//
//  DashboardHomeViewModel.swift
//  Hackers
//
//  Reads playerHistory and courseHistory from primary player for home display.
//

import Foundation

@MainActor
final class DashboardHomeViewModel: ObservableObject {
    @Published private(set) var recentPlayers: [PlayerHistoryEntry] = []
    @Published private(set) var topPlayers: [PlayerHistoryEntry] = []
    @Published private(set) var recentCourses: [CourseHistoryEntry] = []
    @Published private(set) var topCourses: [CourseHistoryEntry] = []
    @Published private(set) var isLoading = false

    private var primaryPlayerID: String?

    func load(primaryPlayerID: String?) async {
        guard let playerID = primaryPlayerID else {
            recentPlayers = []
            topPlayers = []
            recentCourses = []
            topCourses = []
            return
        }
        self.primaryPlayerID = playerID
        isLoading = true
        defer { isLoading = false }

        switch await FirebaseService.shared.getPlayerByID(playerID) {
        case .success(let player):
            let entries = Array(player.playerHistory.values)
            recentPlayers = entries.sorted { a, b in
                let aLast = a.lastPlayedAt?.unix ?? 0
                let bLast = b.lastPlayedAt?.unix ?? 0
                return aLast > bLast
            }
            topPlayers = entries.sorted { $0.roundsPlayed > $1.roundsPlayed }

            let courseEntries = Array(player.courseHistory.values)
            recentCourses = courseEntries.sorted { $0.lastPlayedAt.unix > $1.lastPlayedAt.unix }
            topCourses = courseEntries.sorted { $0.roundsPlayed > $1.roundsPlayed }

        case .failure:
            recentPlayers = []
            topPlayers = []
            recentCourses = []
            topCourses = []
        }
    }

    func refresh() async {
        await load(primaryPlayerID: primaryPlayerID)
    }
}
```

---

### 1.6 `Hackers/Features/Dashboard/RecentPlayersView.swift`

**Purpose:** Full player history with select mode for pre-queue into game lobby.

```swift
//
//  RecentPlayersView.swift
//  Hackers
//
//  Full player history + select mode for pre-queue into game lobby.
//

import SwiftUI

struct RecentPlayersView: View {
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @ObservedObject var homeViewModel: DashboardHomeViewModel

    let palette: DesignPalette
    let onDismiss: () -> Void
    let onAddToRound: ([String]) -> Void
    let onRouteToLobby: (String) -> Void

    @State private var isSelectMode = false
    @State private var selectedPlayerIDs: Set<String> = []

    private var allPlayers: [PlayerHistoryEntry] {
        homeViewModel.recentPlayers
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(allPlayers, id: \.playerID) { entry in
                        row(for: entry)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.fire(.light)
                        onDismiss()
                    } label: {
                        Icon(name: "f00d", size: 18, weight: .solid)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(width: 44, height: 44)
                            .glassCardEffect(shape: .circle, interactive: false)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSelectMode {
                        Button("Add to round") {
                            Haptics.fire(.light)
                            onAddToRound(Array(selectedPlayerIDs))
                        }
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(selectedPlayerIDs.isEmpty ? Color.neutral : Color.accentGreen)
                        .disabled(selectedPlayerIDs.isEmpty)
                    } else {
                        Button("Select") {
                            Haptics.fire(.light)
                            isSelectMode = true
                        }
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                    }
                }
            }
        }
    }

    private func row(for entry: PlayerHistoryEntry) -> some View {
        Button {
            Haptics.fire(.light)
            if isSelectMode {
                if selectedPlayerIDs.contains(entry.playerID) {
                    selectedPlayerIDs.remove(entry.playerID)
                } else {
                    selectedPlayerIDs.insert(entry.playerID)
                }
            }
        } label: {
            HStack(spacing: 12) {
                if isSelectMode {
                    Image(systemName: selectedPlayerIDs.contains(entry.playerID) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selectedPlayerIDs.contains(entry.playerID) ? Color.accentGreen : Color.neutral3)
                }

                DashboardPlayerRow(entry: entry, palette: palette)
            }
        }
        .buttonStyle(.plain)
    }
}
```

**Flow:** Select → Add to round → `onAddToRound(ids)` → parent sets `preQueuedPlayerIDs`, dismisses, presents `CourseSelectionView` → on creation, routes to lobby → `GameLobby` adds pre-queued players.

---

### 1.7 `Hackers/Features/Dashboard/RecentCoursesView.swift`

**Purpose:** Full course history with "Play again" on each row.

```swift
//
//  RecentCoursesView.swift
//  Hackers
//
//  Full course history with "Play again" on each row.
//

import SwiftUI

struct RecentCoursesView: View {
    @ObservedObject var homeViewModel: DashboardHomeViewModel

    let palette: DesignPalette
    let onDismiss: () -> Void
    let onPlayAgain: (CourseHistoryEntry) -> Void

    private var allCourses: [CourseHistoryEntry] {
        homeViewModel.recentCourses
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(allCourses, id: \.compositeKey) { entry in
                        DashboardCourseRow(
                            entry: entry,
                            palette: palette,
                            rank: nil,
                            onPlayAgain: { onPlayAgain(entry) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.fire(.light)
                        onDismiss()
                    } label: {
                        Icon(name: "f00d", size: 18, weight: .solid)
                            .foregroundStyle(palette.foregroundColor)
                            .frame(width: 44, height: 44)
                            .glassCardEffect(shape: .circle, interactive: false)
                    }
                }
            }
        }
    }
}
```

---

## 2. Modified Files

### 2.1 `Hackers/Features/Dashboard/DashboardView.swift`

**Removed:**
- `showSetHomeCourse` state
- `SetHomeCourseView` sheet
- `onSetHomeCourse` callback passed to `DashboardHomeView`

**Current state:** No home course UI. `DashboardHomeView` receives `viewModel`, `palette`, `sortedRounds`, `activeRounds`, `onRoundTap`, `onRouteToLobby`.

---

### 2.2 `Hackers/Features/Dashboard/DashboardHomeView.swift`

**Complete rewrite.** Structure:

- **Enums:** `PlayersSegment` (Recent | Top), `CoursesSegment` (Recent | Top)
- **State:** `homeViewModel`, segment controls, sheet/covers for RecentPlayersView, RecentCoursesView, CourseSelectionView (play again + pre-queue)
- **Sections:**
  1. `navBarSpacer` + `homeNavBar`
  2. `activeRoundSection` (unchanged)
  3. `recentPlayersSection` — segment control, 5 `DashboardPlayerRow`, "See all" → RecentPlayersView
  4. `recentCoursesSection` — segment control, 5 `DashboardCourseRow`, "Play again" chip, "See all" → RecentCoursesView

**Key code — `recentPlayersSection`:**

```swift
@ViewBuilder
private var recentPlayersSection: some View {
    let players = Array(displayedPlayers.prefix(5))
    if players.isPopulated || homeViewModel.recentPlayers.isPopulated || homeViewModel.topPlayers.isPopulated {
    VStack(spacing: 12) {
        HStack {
            Text("Players you've played with")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            Picker("", selection: $playersSegment) {
                ForEach(PlayersSegment.allCases, id: \.self) { seg in
                    Text(seg.rawValue).tag(seg)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
            Button("See all") {
                Haptics.fire(.light)
                showRecentPlayers = true
            }
            .fontStyle(kFontName, size: 14, weight: .semibold)
            .foregroundStyle(Color.accentGreen)
        }

        VStack(spacing: 8) {
            ForEach(players, id: \.playerID) { entry in
                DashboardPlayerRow(entry: entry, palette: palette)
            }
        }
    }
    .padding(.horizontal, 16)
    }
}
```

**Key code — `playAgain(for:)`:**

```swift
private func playAgain(for entry: CourseHistoryEntry) {
    Task {
        let course: Course?
        switch entry.courseIDType {
        case .courseAPI:
            if let id = Int(entry.courseID),
               let apiCourse = try? await GolfCourseAPI.shared.getCourse(by: id) {
                course = Course(from: apiCourse)
            } else {
                course = nil
            }
        case .manual:
            switch await FirebaseService.shared.getCourseByID(entry.courseID) {
            case .success(let c): course = c
            case .failure: course = nil
            }
        }
        await MainActor.run {
            if let course {
                playAgainCourse = course
                showPlayAgainSheet = true
            }
        }
    }
}
```

---

### 2.3 `Hackers/Features/Dashboard/DashboardViewModel.swift`

**Removed:**
- `homeCourseName`, `homeCourseApiID`, `homeCourseTeeID`
- `loadHomeCourse()`, `refreshHomeCourse()`, `playAtHomeCourse()`

**Retained:** `currentPlayerID`, `filteredRounds`, `checkForStalledCompletions`, `stalledCompletionInfo`, etc.

---

### 2.4 `Hackers/Shared/Models/Player/Player.swift`

**Added properties:**

```swift
var playerHistory: [String: PlayerHistoryEntry]
var courseHistory: [String: CourseHistoryEntry]
var processedRoundIds: [String]
```

**CodingKeys:**

```swift
case playerHistory = "player_history"
case courseHistory = "course_history"
case processedRoundIds = "processed_round_ids"
```

**Custom init/encode/decode:** Uses `decodeIfPresent` for new fields so existing Firestore documents still decode.

---

### 2.5 `Hackers/App/Session/AppSession.swift`

**Added:**

```swift
@Published var preQueuedPlayerIDs: [String]? = nil
```

Used for RecentPlayersView → CourseSelectionView → GameLobby pre-queue flow.

---

### 2.6 `Hackers/Core/Firebase/Collections/Firebase+Player.swift`

**Added method:**

```swift
func updatePlayerHistoryAndCourseHistory(
    playerID: String,
    roundID: String,
    participants: [RoundParticipant],
    courseInfo: CourseInfo?,
    currentPlayerID: String,
    playedAt: Time = .init()
) async
```

**Behavior:**
- Skips if `roundID` is in `processedRoundIds`
- For each other participant: upserts `playerHistory[playerID]`, appends `RoundPlayedRef(roundID, playedAt)`, updates `name`
- For course: upserts `courseHistory[key]`, increments `roundsPlayed`, sets `lastPlayedAt`
- Appends `roundID` to `processedRoundIds`
- Persists via `player.put()`

---

### 2.7 `Hackers/Features/Round/GameLobby/GameLobby.swift`

**Added state:**

```swift
@State private var isCurrentUserHost = false
```

**In `.task` (pre-queued players):**

```swift
if let preQueued = appSession.preQueuedPlayerIDs, !preQueued.isEmpty {
    switch await FirebaseService.shared.getPlayersByIDs(preQueued) {
    case .success(let players):
        try? await roundSession.addPlayers(players, teeGroupSize: 4)
    case .failure:
        break
    }
    appSession.preQueuedPlayerIDs = nil
}
```

**In `.onReceive(roundSession.$snapshot)`:**
- Sets `isCurrentUserHost` from participants
- When `status == .live`: calls `FirebaseService.shared.updatePlayerHistoryAndCourseHistory(...)` for current player

**Start button:**

```swift
GlassButton(
    title: isEditMode ? "Confirm changes" : (isCurrentUserHost ? "Start round" : "Waiting for host..."),
    tintColor: .accentGreen,
    isDisabled: .constant(!isEditMode && !isCurrentUserHost),
    ...
)
```

---

### 2.8 `Hackers/Features/Round/GameLobby/Player/AddPlayerView.swift`

**Added state:**

```swift
@State private var recentPlayers: [Player] = []
@State private var suggestedPlayers: [Player] = []
@State private var isLoadingHistory = false
```

**Replaced "Recent (coming soon)" and "Nearby (coming soon)" with:**

- **Recent:** Sorted by `lastPlayedAt` descending from primary player's `playerHistory`
- **Suggested:** Top players by frequency in last 90 days (filter `rounds` by `playedAt`)

**Added `loadPlayerHistory()`:**

```swift
fileprivate func loadPlayerHistory() async {
    guard let primary = await AppData.shared.getPrimaryPlayer() else { return }
    let excludedIDs = Set(snapshot.participants.compactMap(\.playerID))
    isLoadingHistory = true
    defer { isLoadingHistory = false }

    let entries = primary.playerHistory.values.filter { !excludedIDs.contains($0.playerID) }
    let recentEntries = entries.sorted { a, b in
        let aLast = a.lastPlayedAt?.unix ?? 0
        let bLast = b.lastPlayedAt?.unix ?? 0
        return aLast > bLast
    }
    let ninetyDaysAgo = (Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast).timeIntervalSince1970
    let suggestedEntries = entries
        .map { entry -> (PlayerHistoryEntry, Int) in
            let count = entry.rounds.filter { $0.playedAt.unix >= ninetyDaysAgo }.count
            return (entry, count)
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
        .map(\.0)

    let recentIDs = recentEntries.map(\.playerID)
    let suggestedIDs = suggestedEntries.map(\.playerID)
    let allIDs = Array(Set(recentIDs + suggestedIDs))

    guard allIDs.isPopulated else {
        recentPlayers = []
        suggestedPlayers = []
        return
    }

    switch await FirebaseService.shared.getPlayersByIDs(allIDs) {
    case .success(let players):
        let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        recentPlayers = recentIDs.compactMap { byID[$0] }
        suggestedPlayers = suggestedIDs.compactMap { byID[$0] }
    case .failure:
        recentPlayers = []
        suggestedPlayers = []
    }
}
```

---

### 2.9 `Hackers/Features/Dashboard/DashboardRoundHistoryView.swift`

**Changes:**
- Removed `.padding(.vertical, 16)` from `ForEach`
- Reduced `LazyVStack(spacing: 12)` to `LazyVStack(spacing: 8)`

```swift
ScrollView(showsIndicators: false) {
    LazyVStack(spacing: 8) {
        ForEach(viewModel.filteredRounds(from: sortedRounds), id: \.self) { round in
            Button { ... } label: {
                DashboardRoundTile(round: round, palette: palette)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 120)
    }
}
```

---

### 2.10 `Hackers.xcodeproj/project.pbxproj`

**Added file references and build phases for:**
- `DashboardPlayerRow.swift`
- `DashboardCourseRow.swift`
- `DashboardHomeViewModel.swift`
- `RecentPlayersView.swift`
- `RecentCoursesView.swift`
- `PlayerHistoryEntry.swift` (in Player group)
- `CourseHistoryEntry.swift` (in Player group)

---

## 3. Removed / Unused

### 3.1 Home Course

- **DashboardView:** No `showSetHomeCourse` or `SetHomeCourseView` sheet
- **DashboardHomeView:** No `homeCourseSection` or `onSetHomeCourse`
- **DashboardViewModel:** No home course state or methods

### 3.2 SetHomeCourseView.swift

- File still exists but is no longer referenced
- Can be deleted if not used elsewhere

---

## 4. Data Flow Summary

### 4.1 History Update (lobby → live)

1. Host taps "Start round" in GameLobby
2. `roundSession.activateLiveRound()` runs
3. `roundSession.$snapshot` emits with `status == .live`
4. Each client calls `FirebaseService.updatePlayerHistoryAndCourseHistory(...)` for its primary player
5. Player doc gets updated `playerHistory`, `courseHistory`, `processedRoundIds`

### 4.2 Pre-queue Flow (RecentPlayersView → GameLobby)

1. User taps "See all" in Players section → RecentPlayersView
2. User taps "Select", selects players, taps "Add to round"
3. `onAddToRound(ids)` → `appSession.preQueuedPlayerIDs = ids`, sheet dismissed, CourseSelectionView presented
4. User picks course, round created → `onRouteToLobby(roundID)`
5. GameLobby loads; in `.task`, if `preQueuedPlayerIDs` is set, fetches players and calls `roundSession.addPlayers(players)`, then clears `preQueuedPlayerIDs`

### 4.3 Play Again Flow

1. User taps "Play again" on course row
2. `playAgain(for: entry)` fetches `Course` (GolfCourseAPI or Firebase for `.manual`)
3. Presents CourseSelectionView with pre-filled course
4. On creation, routes to lobby

---

## 5. Round History Search

`DashboardViewModel.filteredRounds(from:)` filters by:
- **Course name** (from `round.configuration.courses.first?.courseInfo.name`)
- **Share code** (`round.shareCode`)

Search is case-insensitive and uses `roundsSearchText` from the SearchBar.
