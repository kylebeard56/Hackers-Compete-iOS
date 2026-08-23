# Live Round Staged Enhancements

Comprehensive plan for user testing feedback fixes and UI enhancements, with completion status.

---

## Bugs

| # | Description | Status |
|---|-------------|--------|
| 1 | Round only started for host; other users remained in lobby. After re-joining, still showed lobby. | Not started |
| 2 | Active round not shown on dashboard after joining; users had to enter join code each time. | Not started |
| 3 | iPhone 13 / smaller text: weird padding on player rows; glass buttons had green tint, capsules inside black borders. | Partial – glass capability + ScaledMetric |
| 4 | Hole tab: tapping hole 1 from hole 2 did nothing. | Done |
| 5 | Swipe lag when changing holes. | Done |
| 6 | Lobby remains in nav path after going live; exit should return to dashboard. | Not started |

---

## UI Enhancements

### Stage 1: Round Sync & Navigation (Done)

- [x] `onReceive` for round status when host starts
- [x] `replacingCurrent: true` when navigating to live round
- [x] Fix `round.players` / participant sync
- [x] `loadRounds` after join

### Stage 2: Glass & Accessibility (Done)

- [x] Glass effect capability (fallback to material on older devices)
- [x] `@ScaledMetric` / `CappedScaledMetric` for dynamic layout
- [x] Max text scale 115% (constant in `Constants.swift`)
- [x] `@ScaledMetric` values not private (extensions access)
- [x] `PlayerScoringRow`, `LeaderboardRowView`, `LiveRound`, `LiveHoleScoringView`, `GameLobby`

### Stage 3: Live Round Layout & Hole Details (Done)

- [x] Hole tab in nav header (3 holes visible, 2pt padding)
- [x] Simple `ScrollView` for scorecard + leaderboard (no ObservableScrollView / preference keys)
- [x] Hero card: "Details for Hole #" with Par, Yards, Hcp
- [x] Four glass cubes: Par, Yards, Hcp, Tee
- [x] Tee chip tappable with `chevron.right`, inline with "TEE" label
- [x] All course tees in menu; participant names as subtitle per tee
- [x] Default tee: highest yardage
- [x] Hole details card swipes with scorecard/leaderboard
- [x] Hole tab tap bug fix (binding drives scroll)
- [x] Shadow fix on hole info card
- [x] `navPadding` = invisible placeholder header (0 opacity, disabled)

### Stage 4: Leaderboard Footer & Weather (Done)

- [x] Course name at bottom of leaderboard (subtitle, leading)
- [x] "Last updated at [local time]"
- [x] WeatherKit integration (temp, humidity, wind)
- [x] Apple Weather attribution (logo + legal link)
- [x] `WeatherSnapshot.sample` for previews

### Stage 5: Settings Menu & Name Display (Done)

- [x] Settings gear opens `Menu` (was non-functional button)
- [x] Edit round – fullscreen `GameLobby` sheet, "Confirm changes" CTA
- [x] Share round – `ShareRoundView` sheet (QR code)
- [x] Preferences > Name display > "J. Smith" or "John S."
- [x] Finish round – fake door (destructive style, no action)
- [x] Name format: `NameDisplayFormat` (firstInitialLastName, firstNameLastInitial)
- [x] Default: `firstNameLastInitial` ("John S."); local variable per round (no UserDefaults)
- [x] Applied to: tee menu subtitles, `LeaderboardRowView`, `PlayerScoringRow`
- [x] `ViewThatFits` for name in `LeaderboardRowView`
- [x] Score circle and player name + dots tappable to open full scorecard

### Stage 6: Scorecard Enhancements (Not started)

- [ ] Tap score in `FullScorecardView` to change (popover / horizontal glass capsule)
- [ ] Scorecard visibility sheet – toggle who is visible
  - Nav: X, "Scorecard visibility", "Select all" / "Deselect all"
  - Chips: tee group, team, etc.
  - Player rows: initials, name, visibility toggle
  - Footer: "Apply", "Reset"
- [ ] Score chip: add number in parens – "Double Bogey (6)"
- [ ] Abbreviations: D Bogey, T Bogey, Q Bogey; 5x Bogey, 6x Bogey for 5-over, 6-over
- [ ] Hide net label when user has no strokes (same chip height)

### Stage 7: Scoring Flow (Not started)

- [ ] `LiveHoleScoringView`: flow through tee order (e.g. tap player 4 → 1,2,3,4)
- [ ] Empty state (par) saves when changing players
- [ ] CTA: "Finish Hole #" instead of "Complete Hole"
- [ ] Completion: grey text → accent green + checkmark
- [ ] Hide sheet first, then save scores in background (reduce lag)
- [ ] Auto-navigate to next unscored hole after entering all scores
- [ ] On round entry, navigate to next unscored hole

### Stage 8: Hole Tab Styling (Not started)

- [ ] Tiny checkmark (10–11pt) next to hole # when scored
- [ ] Keep "Hole" in label (e.g. "Hole 1 ✓")
- [ ] Past scored: `foregroundColor`
- [ ] Current: bold `accentPurple` + purple underline
- [ ] Unscored: grey
- [ ] No checkmark on selected hole
- [ ] Error state: `systemError` + exclamation triangle (missing score)

### Stage 9: Skeleton & Misc (Partial)

- [x] Skeleton loader alignment fixes
- [ ] Revisit skeleton for leaderboard row (segment controls)

### Stage 10: Spectator Mode (Not started)

- [ ] Join as spectator (framework exists, disabled)
- [ ] Spectator: no edit permissions, no scorecard tile, read-only
- [ ] Can view leaderboard

---

## Food for Thought

- Hole tab: more obvious scored indication (implemented in Stage 8)
- Tee box toggle for par/yardage when multiple tees in group (done in Stage 3)
- Spectator mode (Stage 10)

---

## Key Files

| Area | Files |
|------|-------|
| Live round | `LiveRound.swift`, `LiveRound+Scoring.swift` |
| View model | `LiveRoundViewModel.swift` |
| Hole selector | `HoleWindowSelector` (in LiveRound.swift) |
| Scorecard | `PlayerScoringRow.swift`, `FullScorecardView.swift`, `ScorecardSheet.swift` |
| Leaderboard | `LeaderboardRowView.swift` |
| Scoring | `LiveHoleScoringView.swift` |
| Lobby | `GameLobby.swift` |
| Weather | `WeatherService.swift` |
| Constants | `Constants.swift` |

---

## Notes

- **Target membership:** New files must be added to app target in Xcode.
- **Text scaling:** 115% max; constant in `Constants.swift`.
- **Glass:** `GlassEffectCapability` + `knownProblematicIdentifiers` for device fallback.
