# Hackers iOS App Redesign PRD

Last reviewed: 2026-06-02  
Source: Current SwiftUI codebase in `Hackers/Features`, `Hackers/App`, `Hackers/Core`, and supporting docs.

## 1. Product Summary

Hackers is an iPhone-first golf competition app for organizing casual and competitive rounds, inviting players, configuring golf game formats, scoring live, reviewing outcomes, and running multi-round experiences such as leagues, trips, and tournaments.

The redesign should preserve the app's current functional depth while making the experience easier to scan, faster to operate one-handed on a course, and more legible for users who are joining a round or series without knowing the app.

## 2. Product Goals

- Help a golfer start or join a round with minimal friction.
- Make pre-round setup understandable even when formats, teams, tee groups, handicaps, and matchups are enabled.
- Make live scoring fast, reliable, and readable outdoors.
- Give players clear post-round outcomes and drill-down scorecards.
- Support commissioner-led multi-round experiences with enough structure for leagues while staying flexible for trips and tournaments.
- Provide a redesign-ready product map for an external UI tool, including all meaningful mobile screens, sheets, role states, and interaction states.

## 3. Primary Users

### Host

Creates a round, chooses a course, invites players, configures format/rules, manages players, starts the round, and may edit/complete the round.

### Player

Joins a round or series, claims their player identity, enters scores, views leaderboards, signs scorecards, and reviews results.

### Spectator

Joins a round without claiming a player slot and views live scoring/results where permitted.

### Series Commissioner

Creates and manages a league/trip/tournament series, adds members, schedules rounds, configures standings and handicap rules, manages announcements, and reviews/syncs completed rounds.

### Series Member

Joins a series, participates in rounds, RSVPs when attendance is enabled, views standings, opens linked rounds, and may leave the series.

## 4. App Information Architecture

### Entry And Root Navigation

- `AuthView` is the first visible surface.
- Authenticated users route into `DashboardView`.
- The app uses a SwiftUI `NavigationStack` with these major destinations:
  - Authentication
  - Minimum app version blocker
  - Dashboard
  - Game lobby
  - Live round
  - Round outcome
  - Series detail
- Deep links can open join flows for rounds or series.

### Main Feature Areas

| Area | Core Screens |
| --- | --- |
| Onboarding and join | Auth, legal, find round/series, QR scan, claim player/member, guest/auth choice |
| Dashboard | Home, round history, profile, recent players, recent courses |
| Round setup | Course selection, course confirmation, course edit, game lobby, player management, share round |
| Live round | Hole scoring, score entry sheet, leaderboard, matchups, full scorecard, complete round |
| Round outcome | Personal summary, course breakdown, leaderboard, matchup results, individual scorecard |
| Series | Rounds, roster, standings, settings, handicap settings, attendance, awards, announcements, CSV export |

## 5. Design Principles For Redesign

- Mobile-first and iPhone-first. Optimize for touch, glare, gloves, and one-handed use.
- Keep golf action surfaces dense but not cramped. Live scoring should prioritize speed over decoration.
- Use progressive disclosure for advanced competition settings.
- Make role permissions obvious: host, guest, spectator, commissioner, member.
- Preserve bottom tab strips and page-based hub navigation where they help orientation.
- Avoid burying the next primary action. Each screen should have one obvious next step.
- Treat destructive actions with confirmations and plain-language consequences.
- Support light and dark mode.
- Show skeletons and loading placeholders without shifting layout unexpectedly.

## 6. Global Interaction Patterns

### Navigation

- Major hubs use horizontal paging with a bottom glass tab strip:
  - Dashboard: Home, Rounds, Profile
  - Series: Rounds, Roster, Standings
  - Round outcome: Leaderboard, Matchups when applicable
- Top navigation commonly uses:
  - Close/back circular icon button
  - Center title card
  - Right-side menu/share/settings action
- Sheets are heavily used for sub-flows. Redesign should distinguish:
  - Short decision sheets
  - Full configuration sheets
  - Full-screen task flows

### Input And Feedback

- Haptics are fired on most navigation and selection interactions.
- Search uses debounced text entry.
- Loading states use skeleton rows, progress indicators, and button loading states.
- Errors appear as banners, alerts, or toasts depending on severity.
- Menus are used for compact option sets.
- Segmented controls are used for mode switching.
- Context menus exist for round tile actions such as enter/archive/delete.

### Mobile State Requirements

Every redesigned primary screen should include:

- Empty state
- Loading state
- Error state where data/network can fail
- Disabled state for unavailable actions
- Role-restricted state
- Keyboard-focused state for text or numeric entry
- Safe-area-aware top and bottom chrome

## 7. Onboarding And Join

### 7.1 Auth Screen

Source: `AuthView`

#### User Goals

- Sign in quickly.
- Continue if already authenticated.
- Join a round or series by code without needing to understand the full app.
- Review legal links.

#### Requirements

- Show Hackers branding prominently.
- When signed out, show:
  - Continue with Google
  - Continue with Apple
  - Join with code
- When already authenticated, show:
  - Continue to Hackers
  - Join with code
- Show loading state while app session resolves.
- Show auth failure toast.
- Legal footnote remains available.
- Minimum app version detection must route to a blocker if the build is too old.

### 7.2 Join Round Or Series Lookup

Source: `FindRoundView`

#### User Goals

- Enter a code or scan a QR code.
- Resolve whether the code belongs to a round or a series.
- Recover when a code is invalid.

#### Requirements

- Header: "Join round or series".
- Text field with uppercase-friendly code input.
- QR scanner entry button.
- Continue CTA.
- QR scanner full-screen camera view with:
  - Scan frame
  - Close button
  - Scan error banner
- If a code matches both a round and a series, show an alert asking the user to choose which target to join.
- On successful lookup:
  - Round lookup routes to join round confirmation.
  - Series lookup routes to join series confirmation.

### 7.3 Join Round Confirmation

Source: `JoinRoundView`

#### Requirements

- Show round details:
  - Course
  - Host
  - Player count
  - Holes
  - Game format
  - Teams yes/no
  - Strokes/handicaps yes/no
- Require the user to pick their player unless already linked.
- Player selection opens a claim-player sheet.
- Primary action: Join.
- Secondary action: Spectate.
- If anonymous/guest flow needs identity handling, show auth choice sheet.
- If player is already linked, disable player dropdown and show confirmation copy.

### 7.4 Join Series Confirmation

Source: `JoinSeriesView`

#### Requirements

- Show series details:
  - Series name
  - Organizer
  - Status
  - Active member count
- Require the user to pick or claim a player/member unless already linked.
- Primary action: Join.
- Auth/guest handling mirrors round join where applicable.

### 7.5 Claim Player Or Member

Sources: `ClaimPlayerView`, `ClaimSeriesMemberView`, `AuthTile`

#### Requirements

- Show unclaimed offline player/member rows.
- Show already claimed rows separately where useful.
- Allow adding a new offline player where permitted.
- Auth tile supports:
  - Login/signup
  - Continue as guest when allowed
  - Blocking guest mode when not allowed
- Member claim flow can fetch/add the user's primary player.

## 8. Dashboard

Source: `DashboardView`, `DashboardHomeView`, `DashboardRoundHistoryView`, `DashboardProfileView`

### 8.1 Dashboard Shell

#### Requirements

- Background theme.
- Horizontally paged tabs:
  - Home
  - Rounds
  - Profile
- Bottom tab strip with sliding selected capsule.
- Plus menu with:
  - Join round or series
  - Start a new series
  - Play a new round
- Join deep links can open the join sheet from this screen.

### 8.2 Home Tab

#### Active Rounds

- Show active lobby/live rounds that the current player has not signed off as complete.
- Empty state encourages "Play a new round".
- See More routes to Rounds tab.
- Round tile tap routing:
  - Live and not signed: Live round
  - Live and signed: Round outcome
  - Lobby: Game lobby
  - Complete/paused: Round outcome
  - Archived: no action
- Round tile context menu:
  - Enter round
  - Archive round if creator and not archived
  - Delete round if creator, with confirmation

#### My Series

- Show series list with status/round chip.
- Empty state encourages creating a series.
- Tap routes to series detail.

#### Player History

- Segment between Recent and Top.
- Show top five players on Home.
- See All opens recent players sheet.
- Tapping a row opens player profile sheet.
- Player profile can route to a shared round.

#### Course History

- Segment between Recent and Top.
- Show top five courses on Home.
- See All opens recent courses sheet.
- Rows include Play Again action.
- Play Again loads the course and opens course selection prefilled.

#### Loading

- Home holds skeletons for a minimum duration and exits after data or timeout.

### 8.3 Recent Players Sheet

#### Requirements

- Header with close and Select/Cancel toggle.
- Normal mode opens player profile.
- Select mode shows checkmarks and enables multi-select.
- Bottom CTA appears when at least one player is selected: "Next: Pick course".
- Selected players pre-queue into the next created round.

### 8.4 Recent Courses Sheet

#### Requirements

- List all recent courses.
- Each row supports Play Again.
- Close control in toolbar.

### 8.5 Rounds Tab

#### Requirements

- Title: Round history.
- Search by round/course/player/format.
- Filter chips:
  - All
  - Completed
  - Upcoming
  - In Progress
  - Archived
- Optional filter menu can surface common courses, players, and formats.
- Group rounds by month.
- Round tiles support same routing and context menu rules as Home.
- Empty states must respond to filter/search context.

### 8.6 Profile Tab

#### Requirements

- Profile card with avatar initials, display name, joined date, and rounds played count.
- Tap display name to edit via alert.
- Show save error inline.
- Logout button.

## 9. Round Creation And Course Selection

Sources: `CourseSelectionView`, `CourseSelectionConfirmation`, `CourseEditView`

### 9.1 Course Selection

#### User Goals

- Pick a course quickly from recent, nearby, or search.
- Use alternatives when no course can be found.
- Create a simple round without a full course.
- Use AI/OCR to capture scorecard/course data.

#### Requirements

- Header: "Pick your course".
- Search bar with debounced course search.
- Suggestive chips when search is empty:
  - Recent
  - Nearby
- Nearby state:
  - If location authorized, load nearby golf courses.
  - If unauthorized, show location request UI.
- Recent state:
  - Show recent course rows.
  - Empty state with golf illustration.
- Search results:
  - Loading skeleton
  - Count label
  - Course rows with club/location/distance where available
  - No results state with alternative actions
- Floating bottom action cluster:
  - Skip, which opens simple round setup
  - Add/assist menu with:
    - Scan scorecard, then take photo or pick photo
    - Ask AI
    - Add manually
- Sheet mode can be used when modifying a course from lobby/series.

### 9.2 Scorecard Scan

#### Requirements

- Camera/photo picker.
- Notes sheet before scan.
- Optional location assist toggle.
- Vision model selector if exposed.
- Scanning state changes floating action to "Scanning..." with progress.
- Scan failure toast.
- Successful scan opens course draft/editor or confirmation depending on confidence.

### 9.3 Ask AI Course Flow

#### Requirements

- Conversational sheet with example prompts.
- Optional location assist toggle.
- Text model selector if exposed.
- Candidate course selection.
- Draft editor if AI output is unconfirmed.
- Reset conversation on dismiss.
- Error toast for failed AI requests.

### 9.4 Simple Round Setup

#### Requirements

- Let user bypass full course lookup.
- Capture:
  - Course/round name
  - Hole count
  - Starting hole
- Creates a simplified course with friendly score input.

### 9.5 Course Confirmation

#### Requirements

- Top map preview if location exists; themed background fallback if not.
- Show course name, address, distance, phone, website where available.
- Edit button for non-simple courses.
- Hole segment picker:
  - Full 18
  - Front 9
  - Back 9 where available
- Tee selection sheet, required when course has tees.
- Explain that player-specific tees can be changed in lobby.
- CTA title adapts to context:
  - Continue
  - Change course
  - Update course
  - Set as home course
  - Set as default course
- Disable CTA until required tee is selected.

### 9.6 Course Edit

#### Requirements

- Edit/view modes.
- Course name required.
- Address optional with map/address search suggestions.
- Current location action for address autofill.
- Hole and tee editing:
  - Expand holes
  - Rename tee
  - Edit pars/yards/handicaps
  - Validate every hole has tee data
- Save button disabled until valid.
- Draft warning card when editing unconfirmed AI/OCR output.

## 10. Game Lobby

Sources: `GameLobby`, `GameLobby+Course`, `GameLobby+Format`, `GameLobby+Configuration`, `GameLobby+Players`

### 10.1 Lobby Shell

#### Requirements

- Top nav:
  - Close
  - Title: Game Lobby
  - Subtitle: Hosted by [name] when available
  - Share QR/code button
- Scrollable content sections:
  - Course
  - Game format
  - Configuration
  - Player tab picker
  - Player content
- Bottom footer:
  - Add players
  - Start round if current user is host
  - Waiting for host if not host
  - Done in edit mode
- If keyboard is focused on handicap fields, replace footer with keyboard dismiss control.

### 10.2 Course Section

#### Requirements

- If course exists, show:
  - Course name
  - Address/phone/website where available
  - Number of holes
  - Par
  - Tee
  - Yards
  - Start/friendly entry for simple rounds
  - Modify course button
- If course missing, show "No course selected" and Add course button.

### 10.3 Game Format Section

#### Requirements

- Show active template icon, name, and description.
- Change format opens format selection sheet.
- Competition scope:
  - Field
  - Matchup
  - Vegas forced to field
- Shared-score formats show score entry scope controls:
  - Individual
  - Partnership
  - Tee group/team depending on config
- Pair handicap allowance input where shared-score handicaps apply.
- Matchup scoring controls:
  - Full-round comparison
  - Hole-by-hole points
- Team scoring builder for team formats:
  - All
  - Best N
  - Worst N
  - Per hole or per round
- Vegas configuration:
  - Oversized teams mode
  - Selected pair rules
  - Per round or per hole selection
  - Summary text
- Secret/surprise scoring toggle for shared-score formats.

### 10.4 Configuration Section

#### Requirements

- Handicap toggle.
- Handicap options menu when enabled:
  - Entry format: strokes or course handicap when tee rating/slope is available
  - Normalization mode
  - Stroke basis
- Teams toggle, disabled for Vegas if required.
- Team colors toggle when teams enabled.
- Shotgun/sequential tee starts toggle.
- Max score menu, constrained by whether course pars exist.

### 10.5 Player Tabs

Available tabs depend on format:

- Roster: always.
- Tee Groups: always.
- Teams: when teams enabled.
- Matchups: when matchup scope enabled.

#### Roster

- Show player count.
- Sort menu:
  - ABC
  - Team
  - Tee
  - HCP
- Rows show avatar/name plus tee group, tee time, default tee, course handicap where relevant.
- If handicaps enabled, show editable handicap text fields.
- Series league handicaps can lock non-commissioners out of editing.
- Row tap opens Manage Player.

#### Tee Groups

- Show partnership overview when scoring groups exist.
- Show unassigned players section.
- Show tee group tiles.
- Actions:
  - Edit assignment grid
  - Add tee group
  - Set tee time
  - Move/remove players through menus
- Support empty slots with Add players action.

#### Teams

- Show partnership overview when applicable.
- Show shared-score banner for mirroring tee groups as teams.
- Show team shortcut banner when no teams exist:
  - Mirror tee groups
  - Randomize
  - Balance by handicap
- Show unassigned team players unless tee-group mirroring is on.
- Show team tiles.
- Actions:
  - Edit assignment grid
  - Add team
  - Rename team
  - Toggle membership lock when mirroring

#### Matchups

- Show matchup assignment/configuration for valid matchup modes.
- Must support individual, team, and score-owner matchup modes.

### 10.6 Add Players

Source: `AddPlayerView`

#### Requirements

- Header with close and confirm when selected players exist.
- Search Hackers players.
- If no search result, allow adding searched name offline.
- Show selected players section.
- When not searching, show Recent and Suggested players.
- Rows include:
  - Initials avatar
  - Name
  - Verified/online indicator
  - Rounds/together subtitle
  - Add/check/remove button
  - "In Lobby" chip when already added
- Confirm returns selected players to lobby.

### 10.7 Manage Player

Source: `ManagePlayerView`

#### Requirements

- Edit round-specific name.
- Select tee box.
- Select tee group.
- Select team when teams required.
- Edit strokes/handicap unless locked.
- Show computed course handicap when entry format is course handicap.
- Show lock messaging for series-controlled handicaps.
- Host can change host through sheet.
- Remove player destructive confirmation.
- Save disabled until required data is valid.

### 10.8 Player Assignment Grid

Source: `PlayerAssignmentGridView`

#### Requirements

- Full-screen assignment UI for teams or tee groups.
- Columns represent teams/groups.
- Players can move between columns and slots.
- Unassign action supported.
- Add team/group action supported.

### 10.9 Share Round

Source: `ShareRoundView`

#### Requirements

- Title: Share round.
- Subtitle includes course when available.
- QR code for deep link.
- Large share code in monospaced style.
- System ShareLink for URL.
- Clipboard fallback/toast.

### 10.10 Round Activation Errors

#### Requirements

- If starting fails due to missing requirements, show a dedicated sheet.
- Errors should be grouped and actionable.
- Preserve user input and return to lobby.

## 11. Game Formats

Source: `FormatTemplateRegistry`

### Selectable Templates

| Format | Core Behavior | Requirements |
| --- | --- | --- |
| Stroke Play | Lowest total strokes wins | No teams required |
| Stableford | Points relative to par; highest wins | No teams required |
| Vegas | Team/pair Vegas number scoring; lowest cumulative wins | Teams required, minimum 4 players |
| Match Play | Hole wins earn points; highest points wins | Matchups required |
| Individual Matchup | Head-to-head stroke play | Matchups required |
| Best Ball | Best score(s) from each team count | Teams required |
| Best Ball Matchup | Best ball head-to-head | Teams and matchups required |
| Alternate Shot | Partners share one ball/score | Teams/pairs required |
| Captain's Choice | Scramble-style shared team score | Teams required |

### Format Selection Requirements

- Show name, icon, description, category.
- Communicate required teams, matchups, and min/max team sizes.
- Disable or explain invalid choices based on current roster.
- Changing format can alter available tabs and configuration controls.

## 12. Live Round

Sources: `LiveRound`, `LiveRound+Scoring`, `LiveHoleScoringView`, `LiveRound+Matchups`

### 12.1 Live Round Shell

#### Requirements

- Background theme adapts to selected golf theme.
- Top nav:
  - Close
  - Hole selector when on scoring tab
  - "Matchups" title when on matchups tab
  - Settings menu
- Bottom tab strip appears only when matchups are available:
  - Scoring
  - Matchups
- Complete-round floating button appears when the current group can complete.

### 12.2 Hole Navigation

#### Requirements

- Hole selector shows a small window of holes with scoring state.
- Hole pages can be swiped horizontally.
- Tapping a hole animates to that hole.
- Auto-advance can be enabled from settings.
- Swipe hint appears for first unscored hole and dismisses after interaction.
- Respect reduce motion where possible.

### 12.3 Hole Details

#### Requirements

- Show par, yards, handicap, and tee.
- Tee cube opens a tee menu grouped by men's, women's, and other tees.
- Tee choice affects displayed hole yardage/handicap.

### 12.4 Scorecard For Hole

#### Requirements

- Show "Scorecard for Hole N".
- If user cannot score the visible group, hide score entry section.
- If loading, show skeleton rows.
- If group missing, show waiting message.
- Score rows adapt by score owner scope:
  - Individual rows
  - Team/shared rows
  - Partnership shared rows
  - Partnership individual rows
  - Tee group shared rows
- Row tap or enter score opens score entry sheet.

### 12.5 Score Entry Sheet

Source: `LiveHoleScoringView`

#### Requirements

- Sheet detent around tall partial height.
- Header with close, hole info, and save/check.
- Show current player or scoring unit name.
- Horizontal avatar selector for players/scoring units.
- Score input supports:
  - Gross strokes mode
  - Friendly relative-to-par mode
  - Clear score sentinel
  - Max score constrained by round config
  - Net score label when handicaps apply
- Supports shared scoring units with multiple avatars.
- Save and continue/close behavior.
- Show scored badge on completed players/units.

### 12.6 Leaderboard

#### Requirements

- Show leaderboard title and optional subtitle.
- Show scoring chips where multiple computed views exist.
- Show leaderboard mode picker:
  - Individual
  - Team
  - Tee group
- Show gross/net picker when handicaps enabled.
- Individual rows:
  - Place
  - Player name using chosen display format
  - Team color
  - Score/points
  - Thru/progress
  - Pin/favorite action
  - Tap to full scorecard
- Grouped rows show team/tee-group sections.
- Show average break line where computed.
- Secret scoring:
  - Hide scores for non-team users until reveal.
  - Host tapping hidden score prompts reveal.
  - Non-host tapping hidden score gets explanation.
- Footer:
  - Course name
  - Last updated time
  - Live status indicator

### 12.7 Live Series Scoreboard

#### Requirements

- If linked to an eligible series, show a compact live scoreboard tile.
- Show projected points, official start points, and competitor names.
- Indicate "Live" when projections are live.

### 12.8 Vegas Summary

#### Requirements

- When Vegas format is active, show a live Vegas summary tile.
- Summary must clarify team/pair totals and chosen Vegas mode.

### 12.9 Matchups Tab

#### Requirements

- Show gross/net segmented picker when handicaps are enabled.
- Show empty state if no matchup results exist.
- Show matchup tiles:
  - Match index
  - Two sides with score pill
  - Result chip
  - Expanded roster for team/score-owner modes
  - Range mismatch diagnostic if matchup hole ranges do not align
- Participant taps open scorecard drill-down.

### 12.10 Settings Menu

#### Requirements

- Edit round if not spectator.
- Share round.
- Change visible group when allowed.
- Change visible group starting hole when allowed.
- Theme selector.
- Name display selector:
  - J. Smith
  - John S.
- Show/hide scoreless leaderboard rows.
- Auto-swipe toggle.
- Reveal scores if current user is host and secret scoring is active/unrevealed.
- Finish round when allowed.

### 12.11 Complete Round

Source: `CompleteRoundSheet`

#### Requirements

- Header: Complete round?
- Explain scorecard signing.
- If holes are missing scores:
  - Banner lists missing holes/ranges.
  - Mark as max score action.
  - Confirmation alert before applying max score.
- Optional photo upload:
  - Take photo
  - Choose from library
  - Preview selected image
  - Remove selected image
- Primary CTA: Sign scorecard.
- Upload scorecard image to storage if selected.
- Mark current player complete and route/update outcome.

### 12.12 Full Scorecard

Source: `FullScorecardView`

#### Requirements

- Full scorecard view opens from live/outcome.
- Supports score editing when allowed.
- Supports participant/scoring-unit selection.
- Must handle full roster and shared scoring units.

## 13. Round Outcome

Sources: `RoundOutcomeView`, `IndividualScorecardView`

### 13.1 Outcome Shell

#### Requirements

- Yellow/themed background.
- Top nav:
  - Close
  - Title card for selected tab
  - Edit/menu button if editing allowed
- Tabs:
  - Leaderboard
  - Matchups, only when matchup results exist
- If editing allowed:
  - Edit round
  - Name display menu

### 13.2 Leaderboard Page

#### Requirements

- Personal summary tiles when viewer has a participant summary.
- Course summary card:
  - Course name
  - Date
  - Game format
  - Location
  - Holes
  - Par
  - Tee
  - Yards
  - Expandable hole performance rows
  - Hole sort control
  - Metric mode control
- View full scorecard button.
- Overall leaderboard tile:
  - Scoring chips
  - Leaderboard mode picker
  - Gross/net picker when enabled
  - Individual/team/tee group rows
  - Empty state
- Participant row tap opens individual scorecard.

### 13.3 Matchups Page

#### Requirements

- Show empty state if no matchup results exist.
- Show matchup result tiles using same conceptual structure as live matchups.
- Participant taps open individual scorecard.

## 14. Series

Sources: `SeriesView`, `SeriesRosterView`, `SeriesLeaderboardView`, `SeriesLeagueSettingsView`, series sheets

### 14.1 Series Concepts

A series is a multi-round container with members, optional teams/pods, scheduled rounds, standing rules, announcements, attendance, handicap rules, and optional CSV export.

Supported experience presets:

| Preset | Product Language |
| --- | --- |
| League | Recurring season or weekly competition |
| Trip | Multi-round trip with flexible logistics |
| Tournament | Event-style competition |

The redesign must let labels adapt to the preset without changing the underlying interaction model.

### 14.2 Series Shell

#### Requirements

- Top nav:
  - Close
  - Title card with series name
  - Subtitle: Commissioner or current status
  - Settings/share menu
- Tabs:
  - Rounds
  - Roster
  - Standings
- Commissioner bottom plus menu:
  - New round
  - Add players
  - New announcement
- Pull to refresh updates linked round state.

### 14.3 Series Menu

#### Everyone

- Share series.

#### Commissioner

- Announcements.
- Series settings.
- Default course.
- Handicap settings.
- Export CSV.

#### Non-Commissioner

- Leave series with destructive confirmation.

### 14.4 Commissioner Checklist

#### Requirements

Show until setup is complete:

- Add more players.
- Schedule first round.
- Set rules/scoring settings.
- Optional default course.

Rows show required/optional state and completion icons.

### 14.5 League Info Card

#### Requirements

- Show series name.
- Optional description with collapsed/expanded "See more".
- Commissioner edit button.
- Stat tiles:
  - Players
  - Rounds
  - Teams when teams are enabled
  - Completed count where applicable

### 14.6 Rounds Tab

#### Requirements

- Show active announcements above content when present.
- Group rounds by status:
  - Active
  - Upcoming
  - Completed
  - Canceled
- Empty state when no rounds scheduled.
- Round card contents:
  - Status chip
  - Overflow menu
  - Title
  - Course and date/schedule subtitle
  - Current user's score square or placeholder
  - Format caption
  - Opponent summary or tee group context
  - Adjusted chip if round is adjusted
  - Attendance counts where enabled
  - User participation badge when complete/scored
- Round card primary actions by state:
  - Planned: RSVP, preview tee sheet, start round for commissioner
  - Lobby: RSVP, open linked round/start if commissioner
  - Live: review scores for commissioner, open linked round
  - Complete: view awards, open linked round
  - Canceled/other: open linked round when available

### 14.7 Round Overflow Menu

#### Requirements

Menu options vary by role/status and should include relevant actions such as:

- Edit round.
- Preview tee sheet.
- Attendance.
- Awards.
- Correct scores.
- Sync from league.
- Export round CSV.
- Cancel/delete where allowed.

Destructive actions require confirmation.

### 14.8 New Series

Source: `NewSeriesView`

#### Requirements

- Sheet with preset segmented choice:
  - League
  - Trip
  - Tournament
- Name text field with preset-specific placeholder.
- Description copy updates by preset.
- Create CTA disabled until name is non-empty.

### 14.9 New/Edit Series Round

Sources: `NewSeriesRoundSheet`, `EditSeriesRoundSheet`

#### Requirements

Should support:

- Round title/index.
- Scheduled date and default tee time.
- Course selection or default course inheritance.
- Course segment selection.
- Default format config.
- Team/individual matchup structure.
- Attendance defaults.
- Tee sheet planning.
- Handicap participation/customization.
- Save/create CTA with validation.

### 14.10 Attendance

Source: `SeriesRoundAttendanceView`

#### Requirements

- Allow eligible members to mark:
  - Playing/accepted
  - Declined
  - Pending/no response
- Optional declined reason.
- Commissioner can inspect counts and manage round participation.
- Attendance state should feed round creation/tee sheet planning.

### 14.11 Awards And Completion Review

Sources: `SeriesRoundAwardsDetailSheet`, `SeriesCompletionReviewSheet`

#### Requirements

- Completed rounds can show awards.
- Commissioner can review scores before finalizing where needed.
- Score review should make missing/incomplete states clear.
- Awards should explain how points were calculated.

### 14.12 Score Correction

Source: `SeriesRoundScoreCorrectionSheet`

#### Requirements

- Commissioner can correct completed round scores.
- Show player/hole matrix or equivalent.
- Track changed cells.
- Save applies corrections and marks round adjusted.
- Avoid accidental overwrites.

### 14.13 Sync From League

Source: `SeriesRoundSyncSheet`

#### Requirements

- Compare linked round state against current series config.
- Show planned updates before applying.
- Sync teams, roster, tee groups, matchups, course/default settings, or handicap config as supported.
- Preserve completed/archived round safeguards.

### 14.14 Roster Tab

Source: `SeriesRosterView`

#### Requirements

- Roster section:
  - Sort menu: ABC, Team, HCP.
  - Add player button for commissioner.
  - Segment players/spectators when both exist.
  - Empty state.
  - Member rows with name, role, team/pod/handicap context.
  - Tap opens member editor.
  - Handicap breakdown when applicable.
- Teams section:
  - Persistent teams when enabled.
  - Team editor.
  - Team captain/member management.
  - Pods/fixed pairs editor.
- Commissioner can remove members with confirmation.
- Non-commissioner can leave series unless commissioner transfer is required.
- Self role demotion requires confirmation.

### 14.15 Member Editor

Source: `SeriesMemberEditorSheet`

#### Requirements

- Edit member name/role/team/spectator status where allowed.
- Commissioner role transfer/demotion safeguards.
- Handicap override entry where enabled.
- Remove/deactivate member where allowed.

### 14.16 Teams And Pods

Sources: `SeriesTeamEditorSheet`, `SeriesPodEditorSheet`

#### Requirements

- Create/edit team name and visual identity.
- Assign members to teams.
- Manage team captains.
- Create/edit persistent pods/fixed pairs.
- Pod strategies can map into round tee sheet/matchups.

### 14.17 Standings Tab

Source: `SeriesLeaderboardView`

#### Requirements

- Settings summary card:
  - Default course
  - Default format
  - Team points profile
  - Individual points profile
  - Handicaps
  - Teams enabled/off
  - Scoreboard visibility toggle when eligible
  - Manage settings button
- Standings section:
  - If no standings enabled, show empty state prompting settings.
  - If team and individual standings enabled, show segmented picker.
  - Team standings table:
    - Rank
    - Team name
    - Points
    - Wins
    - Rounds
    - Tap team for detail sheet
  - Individual standings table:
    - Placement mode
    - Stats mode
    - Rank, name, points/stats
  - Refresh awards/standings button when rebuild is allowed.
- Round history section with all series rounds and status/results context.

### 14.18 Team Detail

Source: `SeriesTeamDetailSheet`

#### Requirements

- Show team standing details.
- Show member list and round contribution context.
- Make points/wins/rounds understandable.

### 14.19 Series Settings

Source: `SeriesLeagueSettingsView`

#### Requirements

Settings should be grouped and collapsible:

#### League Details

- Name.
- Description.

#### Course Logistics

- Default course.
- Clear default course.
- Default tee.
- Clear default tee.
- Default tee time.
- Clear default tee time.
- Play days weekday picker.
- Course rotation:
  - Fixed
  - Alternate front/back
- Default segment/start segment.

#### Format

- Format template.
- Competition:
  - Field
  - Matchup
- Team score counting when teams enabled:
  - All
  - Best N
  - Worst N
  - Per round/per hole
- Shotgun start default.

#### Points And Awards

- Team points profile selection/editor when teams enabled.
- Individual points profile selection/editor.
- Profiles support placement-style and win/tie/loss style where applicable.

#### Behavior

- Series type preset.
- Use teams toggle.
- Show team standings toggle.
- Show individual standings toggle.
- Allow editing after start toggle.
- Allow commissioner overrides toggle.
- Collect attendance toggle.
- Default attendance when enabled:
  - Pending
  - Accepted
  - Declined
- Default pair grouping:
  - Disabled
  - Align by index
  - Swap pairs

#### Rules Confirmation

- Show whether required rules/configuration are complete.
- Save CTA fixed in footer.

### 14.20 Handicap Settings

Source: `SeriesHandicapSettingsView`

#### Requirements

- Handicap mode selector:
  - Off
  - Fixed/scoring-only style
  - Dynamic/computed style
- Configuration when enabled:
  - Differential multiplier
  - Handicap basis
  - Default par
  - Course rating/slope adjustment toggle
  - Course handicap entry toggle
  - Normalize handicaps toggle
  - Recent score window
  - Games/scores used matrix
  - Score pool policy:
    - Lowest scores
    - Most recent scores
  - Max handicap
  - Minimum scores
- Live preview:
  - Example scores input
  - Computed preview result
- Member handicaps:
  - Baseline scores
  - Overrides
  - Handicap breakdown
- Save CTA.

### 14.21 Announcements

Sources: `SeriesAnnouncementsView`, `SeriesAnnouncementEditorSheet`, `SeriesActiveAnnouncementsSection`

#### Requirements

- Commissioners can create/edit announcements.
- Active announcements appear in series rounds tab.
- Announcement editor supports title/body/status/date constraints where implemented.
- Non-active announcements should be reviewable in management view.

### 14.22 Share Series

Source: `ShareSeriesView`

#### Requirements

- QR code/deep link.
- Share code.
- System share.
- Preset-aware copy.

### 14.23 CSV Export

Source: `SeriesCSVExportOptionsSheet`, `SeriesCSVShareSheet`

#### Requirements

- Commissioner can export series or a selected round.
- Select included rounds.
- Select teams/members when filters apply.
- Select sections:
  - Leaderboard
  - Hole scores
  - Matchups
  - Tee groups
- Show skipped rounds if linked snapshots cannot be loaded.
- Present system share for generated CSV.

## 15. Data And Status Model For Design

### Round Statuses

- Lobby: setup created, not live.
- Live: scoring is active.
- Paused: round interrupted.
- Complete: finished and outcome available.
- Archived: hidden/inactive.

### Series Round Statuses

- Planned: scheduled but no linked active round.
- Lobby: linked round exists and is in setup.
- Live: linked round is active.
- Complete: scored/finalized.
- Canceled: not happening.

### Score Concepts

- Gross score: raw strokes.
- Net score: score adjusted by handicap strokes.
- Friendly score: relative-to-par input for simple rounds.
- Shared score: a team/pair/tee group enters one score.
- Score owner: the entity that owns a score entry, such as participant, partnership, team, or tee group.
- Matchup score: result against an opponent or opposing group.
- Secret scoring: scores are hidden until host reveals.

## 16. Permissions And External Services

### Authentication

- Apple sign-in.
- Google sign-in.
- Anonymous/guest support for join flows.

### Location

- Nearby course discovery.
- Course distance display.
- Course address/current location assistance.
- AI/scorecard location assist toggles.

### Camera And Photos

- QR scanning.
- Scorecard scan.
- Scorecard completion upload.

### Network/Backend

- Firebase is used for auth/data/storage/functions.
- Course search can use external golf course data.
- AI/OCR providers may be used for course and scorecard extraction.

## 17. Accessibility And Usability Requirements

- Tap targets should be at least 44 pt.
- Outdoor readability is critical for live scoring.
- Dynamic type should not break score rows, cards, or buttons.
- Score values should use monospaced digits where rapid comparison matters.
- Avoid color-only status communication; pair colors with labels/icons.
- Support VoiceOver labels for:
  - QR/share buttons
  - Score rows
  - Hidden secret-score interactions
  - Standings tables
  - Destructive actions
- Keyboard dismissal must be available on sheets with text/numeric entry.

## 18. Analytics And Telemetry Touchpoints

Existing code tracks or implies telemetry for:

- Auth viewed.
- Join lookup viewed.
- Join deep link opened/resolved/failed.
- Round setup course selection viewed.
- Course confirmation viewed.
- Course confirmed.
- Course edit opened.
- Lobby viewed.
- Live round viewed.
- Round completion opened.
- Round completed.

The redesign should preserve these instrumentation moments and add event hooks for:

- Format changed.
- Handicap settings changed.
- Team/tee assignment edited.
- Score entered/cleared.
- Secret scores revealed.
- Series settings saved.
- Series round created/started/completed.
- CSV export generated.

## 19. Redesign Deliverables

The external design tool should produce at minimum:

- App map covering all major destinations and sheets.
- Component library:
  - Top nav
  - Bottom tab strip
  - Primary button
  - Glass/secondary button
  - Icon button
  - Search bar
  - Segmented control
  - Menu chip
  - Status chip
  - Player avatar
  - Round tile
  - Series round tile
  - Score row
  - Leaderboard row
  - Standings table row
  - Empty state
  - Skeleton state
  - Error banner
- Mobile screen designs for:
  - Auth
  - Join lookup and QR scanner
  - Join round confirmation
  - Join series confirmation
  - Dashboard Home
  - Dashboard Round history
  - Dashboard Profile
  - Course selection
  - Course confirmation
  - Course edit
  - Game lobby roster/groups/teams/matchups
  - Format selection
  - Add/manage player
  - Share round
  - Live scoring
  - Live score entry sheet
  - Live leaderboard
  - Live matchups
  - Complete round
  - Full scorecard
  - Round outcome
  - Series rounds
  - Series roster
  - Series standings
  - Series settings
  - Series handicap settings
  - Series attendance
  - Series awards/review
  - Series share
- Interaction prototype for:
  - Start round from dashboard
  - Join by QR/code
  - Configure lobby and start
  - Enter live scores and complete round
  - Create series and schedule/start a round

## 20. Open Product Questions

- Should a first-time user be nudged toward joining or starting a round first?
- Should live scoring default to player-specific group visibility or all-groups visibility for commissioners?
- Should map/chat/weather remain hidden until feature-complete or appear as upcoming affordances?
- Should simple rounds be marketed as "quick scorecard" rather than "skip" to reduce ambiguity?
- How much of the advanced format builder should be inline in lobby versus delegated to a dedicated format configuration screen?
- Should the dashboard plus menu separate "Round" and "Series" creation more visually?
- What is the desired hierarchy between individual and team standings in series by default?
- Should series presets have distinct visual identities or only copy/default differences?

