# Live Activity Visual Audit

Date: 08-17-2026

## Audit Scope

Compare the current native Live Activity card variants with the three user-provided visual references, emphasizing screenshot 3.

## Verdict

The revised Lock Screen card is now a close screenshot-3 adaptation with an even leaner information hierarchy: the `figure.golf` progress mark, hole/gross/net cluster, individual position, narrow matchup summary, olive-black surface, and restrained single-color progress treatment all fit without clipping. The redundant player name and progress footer are gone.

## Steps

1. Matchup card — Shows gross/net, `T5 of 8`, counting status, `DOWN 5`, and `5% WIN` in one glance.
2. Individual card — Closely tracks the screenshot-3 solo hierarchy with `T3 OF 24` and radial completion.
3. Team card — Reuses the same hierarchy for `#2`, team score/name, and distance from the lead.

## Remaining Validation

- Validate compact and expanded Dynamic Island layouts on a physical ActivityKit surface.
- Check Always-On dimming and unusually long match-standing values.

## Accessibility Risks

- No aggressive minimum-scale factors remain in the redesigned card.
- Contrast is strong in the clean simulator capture, but Always-On dimming was not verified.

## Evidence Limits

- The final card was rendered from production SwiftUI in a clean native iPhone Simulator harness, not inside the Lock Screen ActivityKit host.
- Dynamic Island was not captured, so its visual similarity cannot be confirmed from screenshots.
