# Glass Content Card Inventory

This document inventories `.glassCardEffect` usages whose primary role is to render a content card or tile wrapper.

Included:
- Surfaces that primarily present informational content blocks, lists, grouped rows, or section payloads.

Excluded:
- Navigation and title chrome
- Tab bars and segmented chrome
- Hole selector chrome
- Buttons, chips, pills, circles, and menu labels
- Search bars, avatars, and other control-only surfaces
- Sheet-only and editor-only flows outside the main screen families below

Important current exception:
- `SeriesRosterView.rosterSection` already uses `forceMaterial: true` for its large roster shell in `Hackers/Features/Series/SeriesRosterView.swift`.

## Dashboard

- `DashboardHomeView.activeRoundSection`
  - File: `Hackers/Features/Dashboard/DashboardHomeView.swift`
  - Role: Outer content card for active rounds

- `DashboardHomeView.seriesSection`
  - File: `Hackers/Features/Dashboard/DashboardHomeView.swift`
  - Role: Outer content card for series

- `DashboardHomeView.recentPlayersSection`
  - File: `Hackers/Features/Dashboard/DashboardHomeView.swift`
  - Role: Outer content card for recent players

- `DashboardHomeView.recentCoursesSection`
  - File: `Hackers/Features/Dashboard/DashboardHomeView.swift`
  - Role: Outer content card for recent courses

- `DashboardProfileView.profileCard`
  - File: `Hackers/Features/Dashboard/DashboardProfileView.swift`
  - Role: Profile summary card

## Game Lobby

- `GameLobby.courseSection`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Course.swift`
  - Role: Course content card when a course exists

- `GameLobby.courseSection`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Course.swift`
  - Role: Empty-state course content card when no course exists

- `GameLobby.gameFormatSection`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Format.swift`
  - Role: Format summary and controls card

- `GameLobby.gameConfigurationSection`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Configuration.swift`
  - Role: Configuration toggles card

- `GameLobby.playersSection`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
  - Role: Roster shell card for the roster tab

- `GameLobby.sharedScoreTeamsBanner`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
  - Role: Informational banner card for shared-score teams

- `GameLobby.teamShortcutsBanner`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
  - Role: Quick setup helper card for teams

- `MatchupCardView.body`
  - File: `Hackers/Features/Round/GameLobby/Accessory/MatchupCardView.swift`
  - Role: Matchup tile

- `GameLobby.teeGroupTile(for:)`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
  - Role: Tee group content card

- `GameLobby.unassignedGroupPlayers(for:)`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
  - Role: Expandable unassigned-player card for tee groups

- `GameLobby.teamTile(for:readOnly:)`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
  - Role: Team content card

- `GameLobby.unassignedTeamPlayers(for:)`
  - File: `Hackers/Features/Round/GameLobby/GameLobby+Players.swift`
  - Role: Expandable unassigned-player card for teams

## Live Round

- `LiveRound.teeGroupScorecard(for:)`
  - File: `Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift`
  - Role: Outer scorecard card for the current hole

- `HoleDetailTilesView.cube(value:label:icon:lineLimit:)`
  - File: `Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift`
  - Role: Compact hole-info tiles

- `LiveRound.leaderboardSection`
  - File: `Hackers/Features/Round/LiveRound/LiveRound+Scoring.swift`
  - Role: Leaderboard content card

- `MatchupTileView.body`
  - File: `Hackers/Features/Round/LiveRound/LiveRound+Matchups.swift`
  - Role: Matchup result card

- `LiveRound.mapContent`
  - File: `Hackers/Features/Round/LiveRound/LiveRound+Map.swift`
  - Role: Map container card

- `LiveRound.mapContent`
  - File: `Hackers/Features/Round/LiveRound/LiveRound+Map.swift`
  - Role: Supporting information card below the map

## Series

- `SeriesActiveAnnouncementsSection.body`
  - File: `Hackers/Features/Series/SeriesActiveAnnouncementsSection.swift`
  - Role: Outer announcements section card

- `SeriesActiveAnnouncementsSection.body`
  - File: `Hackers/Features/Series/SeriesActiveAnnouncementsSection.swift`
  - Role: Inner per-announcement cards

- `SeriesView.commissionerChecklist`
  - File: `Hackers/Features/Series/SeriesView.swift`
  - Role: Commissioner checklist card

- `SeriesView.seriesRoundSkeletonRow()`
  - File: `Hackers/Features/Series/SeriesView.swift`
  - Role: Round skeleton card

- `SeriesView.seriesRoundRow(_:)`
  - File: `Hackers/Features/Series/SeriesView.swift`
  - Role: Round tile

- `SeriesLeaderboardView.settingsSection`
  - File: `Hackers/Features/Series/SeriesLeaderboardView.swift`
  - Role: Leaderboard tab settings card

- `SeriesLeaderboardView.standingsMainSection`
  - File: `Hackers/Features/Series/SeriesLeaderboardView.swift`
  - Role: Leaderboard standings wrapper card across its branches

- `SeriesLeaderboardView.roundHistorySection`
  - File: `Hackers/Features/Series/SeriesLeaderboardView.swift`
  - Role: Round history card

- `SeriesRosterView.rosterSection`
  - File: `Hackers/Features/Series/SeriesRosterView.swift`
  - Role: Outer roster shell, currently forced to material

- `SeriesRosterView.teamCard(_:)`
  - File: `Hackers/Features/Series/SeriesRosterView.swift`
  - Role: Team content card in the roster teams section

## Notes

- This pass is intentionally limited to the main screen families discussed for glass-vs-material review: Dashboard, Game Lobby, Live Round, and Series.
- Sheet-only and editor-only surfaces such as `FullScorecardView`, `SeriesRoundDetailSheets`, `NewSeriesRoundSheet`, `EditSeriesRoundSheet`, and `CompleteRoundSheet` are intentionally excluded from this inventory.
