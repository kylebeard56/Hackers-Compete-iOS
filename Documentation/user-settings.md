# User Settings

Reference: https://app.clickup.com/t/wdx6zf0n2f

Settings is available below the profile/name card. This repository is a native SwiftUI iOS app with no shadcn/Tailwind frontend; the screen uses its existing `DesignPalette` semantic colors and native accessible switches instead.

## Behavior

- Apple Watch and Live Activities are independent and default to OFF. Existing round selections do not opt an account in.
- Preferences are stored in UserDefaults under the canonical Hackers user ID. They survive app launches and signing out/in on the same device. They do not synchronize between devices or survive deleting the app.
- Signing out stops companion sessions and clears round selection without deleting saved preferences. Another account starts with its own saved preferences or OFF defaults.
- Apple Watch gates the existing dedicated WatchConnectivity snapshot and score-command paths. Switching it off clears the watch's round context and rejects incoming Watch score commands, including commands that were awaiting participant resolution.
- Live Activities gates the existing ActivityKit coordinator and manager. Switching it off ends activities with immediate dismissal, cancels pending publication, and stops its companion listener session. Native work is ordered so a rapid OFF/ON still ends the previous activity before restarting.
- Ordinary iPhone scoring, net score calculations, main round session, round resume, and game rules are not gated by these preferences.
- Unsupported/unavailable integrations show explanatory text. A saved ON preference can always be switched OFF, even when the integration is unavailable.

## Apple platform rules

There is no separate Dynamic Island switch. The installed iOS 26.2 SDK's ActivityKit interface has no documented independent visibility control for a persistent Live Activity's Dynamic Island presentation. iOS chooses the presentation on supported devices.

WatchConnectivity stays activated for pairing detection, clearing old context, and rejecting disabled commands; round listeners, round snapshots, and score mutations are gated by the preference. The Apple Watch setting controls the dedicated Hackers watch app. iOS can separately mirror Live Activities to paired devices. The existing supplemental Live Activity presentations remain available; the phone no longer sends the former Watch-specific alert when starting a Live Activity.

Apple documentation: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities

## Verification and limits

`UserCompanionPreferencesTests` covers defaults, independent changes, persisted ON/OFF values, account isolation, sign-out/relaunch behavior, disabled Watch mutations, Watch activation/deactivation, Live Activity activation/deactivation, rapid preference changes, and default-OFF startup cleanup. Native manager OFF guards are also tested. Activation uses the actual coordinator with warm in-memory round sessions; an injected manager records ActivityKit lifecycle calls without relying on OS presentation in unit tests.

The ClickUp ticket was read through the connected ClickUp plugin after the browser fetch failed. Its Apple Watch scope is extended by the explicit Live Activities requirements in the user request. Physical Apple Watch delivery, OS Lock Screen/Dynamic Island rendering, and live authenticated account flows require device verification. Live Activities reuse the existing local update path (`pushType: nil`); remote/background delivery through APNs is not implemented by this change. The only Wolf views found in this repository are legacy placeholders; this feature does not change them or claim to complete Wolf gameplay.

No deployment is part of this change.

## Results — October 16, 2026

- Xcode 26.3 / iPhone simulator: app build passed.
- Focused Settings, companion contract, round resume, and scoring run: 114 passed, 0 failed (`/tmp/HackersSettingsVerifiedTests.xcresult`).
- Final Settings suite including light/dark and accessibility-size rendering: 9 passed, 0 failed (`/tmp/HackersSettingsFinal.xcresult`). Screenshots were exported and visually inspected.
- The broader run exposed an unrelated failure in the pre-existing untracked `ScoringRobustnessTests.testNonpositiveGrossStrokesDoNotEarnPointsOrCompleteHoles`: zero/negative gross strokes can affect totals and hole completion in some formats (`/tmp/HackersSettingsTests.xcresult`). Scoring engine files and that test were left unchanged.
- `git diff --check` passed. Xcode-only project-file sorting was removed. Existing workspace changes were preserved.

[Light Settings screenshot](user-settings/settings-light.png) · [Dark Settings with accessibility text size](user-settings/settings-dark-large-text.png)
