# Hackers — Design specification (product & experience)

**Purpose.** This document describes the end-to-end product experience of the Hackers iOS app for **design**, **research**, and **AI-assisted** workflows. It is grouped by **feature areas** (not by engineering structure). It emphasizes what users see, do, and expect—not implementation details.

**Product in one sentence.** Hackers helps golfers organize rounds, configure how competition works, score live together, review results, and run multi-round experiences (leagues, trips, tournaments) with a commissioner-led setup and member participation.

---

## 1. Brand & experience tone

- **Category:** Native iOS golf companion for social and competitive play.
- **Visual language:** Glass-style surfaces, card-based layouts, golf-course–inspired background themes, accent green as the primary action/highlight color.
- **Interaction:** Haptic feedback on key navigation; horizontal paging for major hubs (e.g. dashboard tabs, series tabs); bottom-aligned tab strips with a sliding selection indicator where applicable.
- **Platform:** iPhone-first; respects system appearance (light/dark), safe areas, and keyboard.

---

## 2. Authentication & first entry

**User goals.** Trust the app, sign in quickly, optionally join an existing round or series without friction, and understand legal/terms expectations.

**Capabilities**

- **Sign in with Apple** and **Sign in with Google** as primary identity options.
- **Continue** path when the user is already signed in on device.
- **Join with code** (or equivalent entry) to connect to an existing round or series from the auth surface.
- **Legal acknowledgment** via footnote/sheet pattern; terms may need acceptance before proceeding.
- **Minimum app version** experience: if the installed build is below the required version, the user sees a blocking screen explaining they must update (design should treat this as a hard stop with clear next step to the App Store).

**Design considerations.** Clear hierarchy: logo, welcome copy, primary sign-in actions, secondary join action. Loading states during auth should not feel “stuck.” Error states should be human-readable (network, cancelled sign-in, etc.).

---

## 3. Dashboard (main hub after sign-in)

**User goals.** Resume play, discover what’s active, start something new, browse history, and manage profile—without hunting.

**Information architecture**

- **Three primary tabs** (horizontal paging): **Home**, **Rounds** (history), **Profile**.
- **Floating “+” menu** (typically on Home): shortcuts to **join** a round or series, **start a new series**, and **play a new round** (single session).

### 3.1 Home tab

- **Active rounds** section  
  - Lists in-progress rounds (lobby or live).  
  - **Empty state** encourages starting a new round.  
  - **“See more”** may route attention to the Rounds tab when many actives exist.  
  - **Round tiles** show course/context and invite tap to enter the correct phase (lobby vs live vs outcome depending on rules).  
  - **Context menu** on tiles (where permitted): enter round, archive, delete—with destructive actions confirmed.

- **Series** section  
  - Surfaces active or relevant **series** (multi-round experiences). Tapping opens the **Series** experience (see Section 8).

- **Players** section  
  - Segments such as **Recent** vs **Top** to browse people the user plays with.  
  - Drill-in lists; ability to **pre-select players** for a future round (then flows into course selection).

- **Courses** section  
  - Segments such as **Recent** vs **Top**.  
  - **Play again** flows reuse a past course to start a new round faster.

- **Player profile sheet** (from a player row)  
  - History-oriented view of that person in the context of shared rounds (for social proof and “play with them again” behavior).

- **Skeleton / loading**  
  - Home may show structured placeholders while data resolves; avoid layout jump when content appears.

- **Round completion prompt** (when applicable)  
  - If a round is “stuck” in a completion state that needs user input, a sheet may ask the user to confirm or resolve—copy should reduce anxiety and explain the consequence.

### 3.2 Rounds tab (history)

- Chronological or recency-sorted **list of rounds**.  
- Tap routes based on **round status** (e.g. resume lobby, enter live round, open outcome).  
- Loading and empty states should match the Home tab quality bar.

### 3.3 Profile tab

- **Profile card:** avatar/initials, **display name** (editable), **join date**, **rounds played** count.  
- **Logout** action.  
- Save feedback and inline error messaging when name changes fail.

### 3.4 Global dashboard behaviors

- **Delete round** confirmation for destructive removal.  
- **Set home course** (where exposed): dedicated flow to declare a default “home” course for convenience.

---

## 4. Starting a round — course selection & course intelligence

**User goals.** Pick a real course quickly, optionally capture tee/hole data from a scorecard, and land in the round lobby ready to invite people.

**Capabilities**

- **Search** for courses by name; **nearby** discovery using device location (when permission granted).  
- **Distance-to-course** presentation helps users pick geographically.  
- **Scorecard capture** (camera/photo): user photographs a scorecard; the app assists with **structured extraction** of course/hole data to reduce manual entry. User may add notes or refine results.  
- **Optional AI-assisted course help** (where enabled): conversational or guided assistance to resolve ambiguous course data, with location assist toggles the user can control.  
- **Location permission** UX: graceful degradation when location is off—explain why nearby search helps and how to enable settings.  
- Successful selection **creates a round** and transitions to the **game lobby** (or equivalent next step).

**Design considerations.** This flow is often the first “serious” task—optimize for speed, trust (what we do with photos/location), and recovery from partial OCR/AI results. Clear **primary** vs **secondary** actions in the footer/header patterns.

---

## 5. Game lobby (pre-round setup)

**User goals.** Invite players, align on format, optionally use handicaps and teams, set tee groups, and start play when everyone is ready.

**Host vs guest**

- **Host/organizer** controls who’s in the round, structure of play, and starting the round.  
- **Guests** join via invite/share and may have constrained editing depending on host settings.

**Roster & players**

- Add/remove participants; support **offline-style players** (e.g. friends not on the app) where product allows.  
- Sorting and roster hygiene (alphabetical, etc.).  
- **Change host** when needed.

**Teams & colors**

- Toggle **teams** on/off.  
- **Team colors** for quick visual scanning in live scoring.  
- Assign players to teams; handle **unassigned** players with clear grouping/expansion.

**Handicaps**

- Enable/disable handicaps for the round.  
- Per-player handicap entry and validation.  
- **Series-aware behavior:** if the round belongs to a series with league handicaps, show **lock** or **commissioner-controlled** messaging so users understand why they can’t edit.

**Matchups**

- Enable head-to-head pairings when the selected format requires or allows them.  
- Visual grid or assignment tools for pairing players/teams.

**Tee groups & pacing**

- **Sequential tee starts** option.  
- **Tee time** picker and editing tee groups.

**Format selection**

- User picks a **game format template** (stroke play, stableford, match play, team formats such as best ball, scramble-style team play, vegas, alternate shot, etc.).  
- Copy should explain **minimum players**, **team requirements**, and **what “winning” means** at a glance.

**Scoring privacy**

- **Secret scoring** mode when the product supports hidden inputs until reveal—surface the mental model clearly.

**Share & join**

- **Share round** / party-code style joining so others can enter the lobby.

**Course changes**

- Edit attached course details from the lobby when corrections are needed.

**Round activation**

- **Start round** transitions to live play.  
- Clear **error** states if activation fails (permissions, network, incomplete requirements).

**Design considerations.** Lobby is dense—use progressive disclosure, strong sectioning, and status chips. Mobile-first: large touch targets for assignments and draggable affordances where used.

---

## 6. Live round (in-play)

**User goals.** Enter scores fast, see standings/matchups, understand position on the course, and finish cleanly.

**Primary surfaces**

- **Scoring** experience: leaderboard and **hole-by-hole** entry; hole navigation (pager/carousel patterns).  
- **Matchups** tab/section when formats require head-to-head presentation alongside the field leaderboard.

**Scorecard & visibility**

- **Full scorecard** view.  
- Controls for **who can see whose scores** / scorecard visibility where product supports it.

**Map (aspirational / staged)**

- Map area may show **satellite/course imagery** with placeholder or future copy for yardage, planning, and cart locations. Design should allow **empty → full** progression without rearranging the whole IA.

**Chat (aspirational / staged)**

- In-round messaging may be present as a **coming soon** or lightweight placeholder—design for future density (text/media) without promising unfinished behavior in marketing strings.

**Ambient context**

- **Weather** or similar contextual info may appear to set expectations (wind/conditions) without blocking scoring.

**Completing the round**

- **Complete round** sheet: confirm totals, next steps, and any series implications.

**Design considerations.** One-handed use on the course; high contrast for sun; minimize steps between holes; skeleton states for slow connections.

---

## 7. Round outcome (post-round)

**User goals.** Understand how everyone finished, inspect hole-level detail, and share bragging rights—or fix mistakes if allowed.

**Capabilities**

- **Personal summary** highlights for the viewer.  
- **Course** summary and navigation context.  
- **Leaderboards** including **grouped** presentations (teams/segments) when applicable.  
- **Hole sorting** and **metric modes** for reviewing patterns (e.g. by hole number vs performance lens).  
- **Participant drill-down** from rows.  
- **Edit round** entry points when policy allows (e.g. commissioner or signed-scorecard rules).

**Design considerations.** Celebration-forward tone options (badges, clear winners) vs analytical tone (tables). Balance stats density with scannability.

---

## 8. Series — leagues, trips, tournaments

**Positioning.** A **Series** is a container for multiple rounds with shared membership and standings over time. The product uses **experience presets** that tune language and defaults:

| Preset | Intent (user mental model) |
|--------|----------------------------|
| **League** | Recurring season-style play: rules, standings, commissioner tooling. |
| **Trip** | Multi-day golf travel: flexible formats, changing pairings, trip-friendly defaults. |
| **Tournament** | Event-style competition with editable defaults across rounds. |

**Roles**

- **Commissioner:** configures the series, schedules rounds, may review completions, manages announcements, and uses advanced controls.  
- **Member:** participates, opens linked rounds, RSVPs when attendance is enabled, and may leave the series.

### 8.1 Series main screen (three tabs)

**Navigation**

- Back to prior hub.  
- **Title** with series name and role/status subtitle (e.g. Commissioner vs member state).  
- **Overflow menu**  
  - Everyone: **Share** invite (preset-specific wording: league vs trip vs tournament).  
  - Commissioner: **Announcements**, **Edit name**, **Settings** (preset-titled: League/Trip/Tournament settings), **Default course**, **Handicap settings**.  
  - Member: **Leave** series (destructive confirmation with preset-aware copy).

**Tab strip:** **Rounds** · **Roster** · **Standings** (horizontal paging).  
**Commissioner + menu:** New round, Add players, New announcement.

**Cross-cutting**

- Pull to refresh.  
- Active **announcements** may appear atop **Rounds** when relevant.  
- **Commissioner checklist** until basics are complete: add players, schedule first round, set scoring rules, optional default course.

### 8.2 Rounds tab

- Grouped lists: **Active**, **Upcoming**, **Completed**, **Canceled** (labels may vary slightly by data).  
- **Round cards** include status, course/date line, format/opponent/tee context, optional attendance tallies, user’s score badge when applicable, and **primary actions** (RSVP, Start round, Open round, Review scores, View awards—depending on state and role).  
- **Overflow per round:** attendance, sync from external league shell (wording depends on preset), awards, edit/duplicate/cancel/delete, export data, correct scores—gated by role/status.

### 8.3 Roster tab

- Segments for **players** vs **spectators** when used.  
- **Roster** list with sorting (e.g. alphabetical, team, handicap).  
- **Teams** management: create/edit teams, assign members, **pods** or sub-groupings where supported, offline guest players.  
- Member actions: edit profile within series scope, remove, role changes, handicap breakdown views.  
- Leave/demote flows with confirmations where destructive.

### 8.4 Standings tab

- **Read-only summary** of key settings: default course, default format, team/individual point profiles, handicap mode, teams on/off.  
- **Manage settings** entry for commissioners.  
- **Team vs Individual** standings segments when both are enabled.  
- **Round history** tying results to standings; path into **awards** for a round.

### 8.5 Series settings & deep sheets (feature capabilities)

These are **modal/sheet flows** invoked from menus or tabs—not separate app roots:

- **Create series** (from dashboard): choose preset, name, short description, create.  
- **Rename series.**  
- **League/Trip/Tournament settings:** large form covering logistics, default format, team vs individual points/awards, behavior flags, confirmation of rules—**Save** as primary action.  
- **Default course** for the series.  
- **Handicap settings:** mode (off / fixed for scoring / dynamic from rounds—wording should match product), parameters, **preview** of index calculation, member table, entry to **baseline scores** and **manual overrides**.  
- **Announcements** list + **editor** for new/edited posts.  
- **Share series** invite experience (QR/visual share patterns).  
- **Add players** to membership.  
- **New scheduled round** composer.  
- **Edit scheduled/completed round** (including format & awards on completed rounds where allowed).  
- **Course selection when starting** a round that doesn’t yet have a resolved course.  
- **Attendance/RSVP** sheet for a round.  
- **Awards** detail for a completed round.  
- **Score correction** after completion.  
- **Sync** from an external league shell when integrations apply.  
- **Completion review** for commissioners when a round needs sign-off.  
- **CSV export/share** when commissioners export results.

**Design considerations.** Presets should **swap copy**, not layout wholesale—design systems should tolerate **League vs Trip vs Tournament** terminology. Commissioner surfaces are power-user dense: use sectioning, progressive disclosure, and confirmation for destructive league actions.

---

## 9. Joining rounds & series

**User goals.** Enter a group round or series with minimal typing; recover from mistakes.

**Entry points**

- **Join with code** from auth or dashboard.  
- **Deep links** from messaging/email: may carry round or series tokens; app routes into the join flow.  
- **Find round** style sheet: search/enter code, then transition into lobby or live play as appropriate.

**Design considerations.** Show **what you’re joining** (round vs series) before committing. Clear **error** states for expired/invalid codes.

---

## 10. Secondary & legacy-adjacent experiences

The product may still expose or transition from **older flows** (e.g. alternate round setup, extensive **side games** catalogs like betting or novelty games). For design exploration:

- Treat **side games** as **optional layers** on top of core scoring—they have their own rulesets and pacing labels (relaxed vs competitive).  
- Any **legacy onboarding** or **subscription/promo code** surfaces should match current visual system if still reachable.

**Design note.** If a feature is marked “coming soon” in-app, external marketing should not promise it.

---

## 11. Trust, privacy, and data (design-facing)

- **Location** is used for nearby course discovery; explain value and offer settings path.  
- **Scorecard photos** imply camera/photo library access; pair with concise privacy copy.  
- **Account identity** is tied to sign-in providers; profile name is editable for display in rounds.

---

## 12. States & quality bar (applies globally)

For each major surface, design should specify:

- **Loading** (skeleton vs spinner—product uses skeletons in several hubs).  
- **Empty** (first-time vs cleared).  
- **Error** (retry, settings, support path).  
- **Permission denied** (location, camera, photos).  
- **Success feedback** (saved settings, round started, series created).  
- **Destructive** confirmations (delete round, leave series).

---

## 13. Open design questions (non-blocking)

- Balance **commissioner power** vs **member clarity** in Series—when to show advanced controls inline vs behind “Manage…”  
- **Map** and **chat** evolution: how much IA space to reserve vs collapse into a single “Tools” area during live play.  
- **Trips vs leagues:** same components with different **default copy** and **checklist emphasis**—validate with trip-specific user tests.

---

*Document version: initial design spec for Hackers iOS. Update when major flows ship or presets change.*
