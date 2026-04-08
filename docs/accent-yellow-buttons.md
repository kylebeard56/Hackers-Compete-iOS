# `accentYellow` controls reference

Inventory of **SwiftUI call sites** that use `Color.accentYellow` / `.accentYellow` for primary actions, chips, badges, or accents. Scope: [`Hackers`](../Hackers) target (not Legacy V2 yellow tokens).

## Primary vs glass and dark mode

| Component | Surface | Dark mode behavior |
|-----------|---------|-------------------|
| **`PrimaryButton`** | **Solid fill** via `buttonColor` (no `glassCardEffect` on the fill). | The pill is **`accentYellow` at full opacity**. It is **not** run through [`glassCardEffect`](../Hackers/Shared/Components/Cards/GlassCardEffect.swift)’s light/dark **veil** stack—so it does **not** “darken” for the same reason glass CTAs do. Contrast depends on label color vs yellow. |
| **`GlassButton`** | **Glass** via [`glassCardEffect`](../Hackers/Shared/Components/Cards/GlassCardEffect.swift) with optional `tint` (`tintColor`). | **Material fallback** (pre–iOS 26, or when native liquid glass is not used): dark mode applies a **darker base veil**, **lower highlight**, and a different base material choice vs light mode, so the control often reads **more subdued / darker** than in light mode. **iOS 26+** path with system `glassEffect` can look different; see implementation in `GlassCardEffect.swift`. |

**Practical rule of thumb:** If the row says **Glass**, expect **scheme-dependent glass treatment** (often darker/more muted in dark mode on the fallback path). If it says **Primary (fill)**, expect a **flat `accentYellow` fill** without that glass veil recipe.

---

## A. Filled primary actions (`PrimaryButton`)

Solid yellow fill; explicit `labelColor` where noted.

| File | Title / role | `buttonColor` | Label color (`labelColor`) |
|------|----------------|---------------|----------------------------|
| [`SeriesView.swift`](../Hackers/Features/Series/Views/SeriesView.swift) (~L1014–1026) | **Awards** (completed series round row) | `Color.accentYellow` | `.white` |
| [`SeriesView.swift`](../Hackers/Features/Series/Views/SeriesView.swift) (~L1030–1042) | Open linked round (adjacent CTA) | `Color.accentYellow` | `.white` |
| [`SeriesRoundDetailSheets.swift`](../Hackers/Features/Series/Sheets/SeriesRoundDetailSheets.swift) (~L1689–1694) | **Complete round** (commissioner force-complete) | `Color.accentYellow` | `.white` |

**Type:** **Primary (fill)** — not glass; no `glassCardEffect` darkening of the yellow fill.

---

## B. Glass primary actions (`GlassButton`)

Yellow appears as **`tintColor`** on a glass capsule (see `GlassButton` + `glassCardEffect`).

| File | Title | `tintColor` | Label color (`labelColor`) |
|------|-------|-------------|----------------------------|
| [`CompleteRoundSheet.swift`](../Hackers/Features/Round/LiveRound/Accessory/Sheets/CompleteRoundSheet.swift) (`ctaFooter`) | **Sign scorecard** | `Color.accentYellow` when all holes scored; else `Color.systemError` | `.white` (both branches) |
| [`RoundCompletionPrompt.swift`](../Hackers/Features/Dashboard/RoundCompletionPrompt.swift) | **Finish** | `.accentYellow` | *Omitted* → defaults to **`labelColor ?? .primary`** (SwiftUI semantic primary per [`GlassButton`](../Hackers/Shared/Components/Buttons/GlassButton.swift)) |

**Type:** **Glass** — dark mode appearance follows `glassCardEffect` / system glass rules as above.

---

## C. Chip pills (`Chip`, not `PrimaryButton` / `GlassButton`)

[`Chip`](../Hackers/Shared/Components/Buttons/Chip.swift) uses `tint` for translucent fill **and** as default **label/icon** color when `foreground` is not overriding (tint wins first). So **yellow tint ⇒ yellow label ink** unless you restructure props.

| File | Chip text | Effective label color |
|------|-----------|------------------------|
| [`SeriesRosterView.swift`](../Hackers/Features/Series/Views/SeriesRosterView.swift) | **Commish** | `Color.accentYellow` |
| [`NewSeriesRoundSheet.swift`](../Hackers/Features/Series/Sheets/NewSeriesRoundSheet.swift) | **Required**, **Review** | `Color.accentYellow` |
| [`EditSeriesRoundSheet.swift`](../Hackers/Features/Series/Sheets/EditSeriesRoundSheet.swift) | **Required**, **Review** | `Color.accentYellow` |

**Type:** **Chip** — small filled/outline pill; not classified as Primary or Glass button.

---

## D. Status badges and static text (not yellow-filled CTAs)

| File | Element | Text / icon color | Background / notes |
|------|---------|-------------------|--------------------|
| [`DashboardRoundTile.swift`](../Hackers/Features/Dashboard/DashboardRoundTile.swift) | `RoundStatusBadge` (complete / archived) | `Color.accentYellow` | `chipColor.opacity(0.2)` |
| [`SeriesView.swift`](../Hackers/Features/Series/Views/SeriesView.swift) | `roundStatusChip` (e.g. **Scored**) | `Color.accentYellow` | Light glass tint on pill |

---

## E. Other `accentYellow` (icons, borders, loaders — not yellow primary buttons)

| File | Usage |
|------|--------|
| [`SeriesRoundDetailSheets.swift`](../Hackers/Features/Series/Sheets/SeriesRoundDetailSheets.swift) | Score-review photo control (icon), trailing labels, row SF Symbols, overlay `ProgressView.tint` |
| [`RoundCompletionPrompt.swift`](../Hackers/Features/Dashboard/RoundCompletionPrompt.swift) | Header icon |
| [`FindRoundView.swift`](../Hackers/Features/Onboard/Join/FindRoundView.swift) | `strokeBorder` |
| [`CompleteRoundSheet.swift`](../Hackers/Features/Round/LiveRound/Accessory/Sheets/CompleteRoundSheet.swift) | Photo drop-zone border when image selected |
| [`BackgroundTheme.swift`](../Hackers/Shared/Components/Theme/BackgroundTheme.swift) | Theme color mapping `.yellow` → `.accentYellow` |

---

## F. Legacy (different tokens)

[`Hackers/Legacy`](../Hackers/Legacy) may use **`systemHackersYellow`**, **`.yellow`**, **`.systemYellow`** on `BigButton` and V2 screens. Those are **not** `accentYellow` and are not listed here.

---

## Maintenance

When adding a new **`accentYellow` CTA**, update this document and state **Primary (fill)** vs **Glass** so dark-mode expectations stay clear.

_Last synced with codebase snapshot; line numbers are approximate._
