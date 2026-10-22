# Commissioner beta test checklist

Use a commissioner account and a test Series/round. Use another account to check member permissions and saved values.

1. **Save with the keyboard open.** Open a player’s Handicap Details → Edit Index. Enter `4.9`, leave the keyboard open, and tap **Save override**. Confirm Save stays visible, the saved Index refreshes, and `4.9` remains after leaving/reopening the screen and relaunching the app. Check a small iPhone too.
2. **Dismiss, cancel, and failed saves.** Confirm **Hide keyboard** dismisses the keyboard without saving. Cancel an unsaved change and confirm the previous value remains. In a test account with a failed save, confirm an error appears, the draft remains, and retry works. Have two commissioners edit the same member; confirm stale edits cannot silently overwrite newer values.
3. **Discover Edit Index and permissions.** Open details for registered and offline players, including a player with no scores or missing Index. Commissioners can edit without adding baseline scores; ordinary members cannot edit another member’s league override. Check that personal, league-calculated, and overridden sources are identified correctly.
4. **Mix tees in a Series.** In Start Round, put five of eight players on longer tees and three on shorter tees. Leave and reopen the draft/lobby. Confirm each selection persists, and the Series remains enabled. Also try a non-Series round.
5. **Keep Index and tees independent.** Give a player an override, then change only that player’s tee. Confirm the Index stays the same while Course HCP/strokes recalculate as applicable. Remove the override and confirm the selected tee remains. Confirm deliberate manual strokes remain separate from the Index.
6. **Check scoring and locked rounds.** Exercise 18 holes and front/back nine with registered and offline players. Create/start the Series round and check net scoring/stroke allocation. Change Index/tees for a future round and confirm started/completed round handicap snapshots stay unchanged.
7. **Production smoke check.** Sign in, open an existing Series, create a test round, enter a score, and check normal navigation. If available, check Watch connectivity and Live Activity updates.

Automated evidence: 1,180 passed / 0 failed / 5 existing opt-in skips; iPhone SE commissioner suite 59 passed with Address Sanitizer. Authenticated Firebase persistence, concurrent real accounts, and physical-device acceptance still require the checks above.
