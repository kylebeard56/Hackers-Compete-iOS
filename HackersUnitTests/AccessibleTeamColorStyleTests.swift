//
//  AccessibleTeamColorStyleTests.swift
//  HackersUnitTests
//

@testable import Hackers
import SwiftUI
import XCTest

final class AccessibleTeamColorStyleTests: XCTestCase {

    func testReadableTextUsesAccentWhenContrastPasses() {
        let palette = DesignPalette(theme: .primary, scheme: .light)
        let style = AccessibleTeamColorStyle.resolve(
            teamColor: .black,
            palette: palette,
            colorScheme: .light,
            surface: .page
        )

        XCTAssertTrue(style.usesAccentForText)
        XCTAssertGreaterThanOrEqual(
            Color.wcagContrastRatio(
                foreground: style.readableText,
                background: palette.backgroundColor,
                colorScheme: .light
            ),
            4.5
        )
    }

    func testReadableTextFallsBackWhenContrastFailsButKeepsAccent() {
        let palette = DesignPalette(theme: .primary, scheme: .light)
        let lowContrastColor = ColorValue(hex: "#F7F7F7").color
        let style = AccessibleTeamColorStyle.resolve(
            teamColor: lowContrastColor,
            palette: palette,
            colorScheme: .light,
            surface: .page
        )

        XCTAssertFalse(style.usesAccentForText)
        XCTAssertGreaterThanOrEqual(
            Color.wcagContrastRatio(
                foreground: style.readableText,
                background: palette.backgroundColor,
                colorScheme: .light
            ),
            4.5
        )
        XCTAssertLessThan(
            Color.wcagContrastRatio(
                foreground: style.accent,
                background: palette.backgroundColor,
                colorScheme: .light
            ),
            4.5
        )
    }

    func testIncreasedAccessibilityContrastUsesStricterThreshold() {
        let palette = DesignPalette(theme: .primary, scheme: .light)
        let normalOnlyContrastColor = ColorValue(hex: "#666666").color
        let normalStyle = AccessibleTeamColorStyle.resolve(
            teamColor: normalOnlyContrastColor,
            palette: palette,
            colorScheme: .light,
            accessibilityContrast: .normal,
            surface: .page
        )
        let increasedStyle = AccessibleTeamColorStyle.resolve(
            teamColor: normalOnlyContrastColor,
            palette: palette,
            colorScheme: .light,
            accessibilityContrast: .increased,
            surface: .page
        )

        XCTAssertTrue(normalStyle.usesAccentForText)
        XCTAssertFalse(increasedStyle.usesAccentForText)
    }

    func testSolidFillTextMeetsContrastForPresetAndCustomColors() {
        for color in [TeamColor.red.value, TeamColor.blue.value, TeamColor.green.value, TeamColor.purple.value, TeamColor.orange.value, ColorValue(hex: "#F7F7F7").color] {
            let style = AccessibleTeamColorStyle.resolve(
                teamColor: color,
                palette: DesignPalette(theme: .primary, scheme: .light),
                colorScheme: .light,
                surface: .solidFill
            )

            XCTAssertGreaterThanOrEqual(
                Color.wcagContrastRatio(
                    foreground: style.solidFillText,
                    background: style.accent,
                    colorScheme: .light
                ),
                4.5
            )
        }
    }
}
