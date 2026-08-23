//
//  NavButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

enum NavigationButtonStyle { case fill, glass }

/// Used mostly for navigation or headers
struct NavButton: View {
    @Environment(\.colorScheme) var colorScheme
    
    var style: NavigationButtonStyle = .fill
    var icon = "f00d"
    var text: String? = ""
    var size: CGFloat = 20
    var weight: FontModule.Weight = .solid
    var color = Color.charcoal
    var background: Color? = nil
    var theme: PaletteTheme = .primary
    var mirror: Bool = false
    var onTap: Callback? = nil
    
    private var designPalette: DesignPalette { DesignPalette(theme: theme, scheme: colorScheme) }
    
    var body: some View {
        Group {
            if #available(iOS 26, *), style == .glass, GlassEffectCapability.useGlassEffect {
                button
                    .background(background ?? Color.systemClear)
                    .clipShape(.circle)
                    .glassEffect(.regular.interactive(), in: .circle)
            } else if style == .glass {
                button
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            } else {
                button
            }
        }
    }
    
    private var button: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap?()
        }) {
            iconView
                .frame(width: size * 2, height: size * 2)
                .background(style == .glass ? .clear : background ?? designPalette.buttonColor)
                .clipShape(Circle())
        }
        .scaleEffect(x: mirror ? -1 : 1, y: 1)
    }
    
    private var iconView: some View {
        Icon(name: icon, size: size, maxSize: size, weight: weight)
            .foregroundStyle(color)
    }
}

#Preview("Primary Light") {
    HStack {
        NavButton(icon: "f00d")
        NavButton(icon: "f053")
        Spacer()
        NavButton(icon: "f00c")
    }
    .alignTop()
    .padding(20)
    .background(Color.backgroundPrimary)
    .colorScheme(.light)
}

struct HandicapOptionsMenu: View {
    @Binding var handicapEntryFormat: HandicapEntryFormat
    @Binding var handicapNormalizationMode: HandicapNormalizationMode
    @Binding var handicapStrokeBasis: SeriesHandicapStrokeBasis?

    let courseHandicapAvailable: Bool
    let competitionScope: CompetitionScope
    let resolvedAutoBasis: SeriesHandicapStrokeBasis?
    let palette: DesignPalette
    var courseHandicapSubtitle: String?
    var onEntryFormatChanged: (HandicapEntryFormat) -> Void = { _ in }
    var onNormalizationModeChanged: (HandicapNormalizationMode) -> Void = { _ in }
    var onStrokeBasisChanged: (SeriesHandicapStrokeBasis?) -> Void = { _ in }

    var body: some View {
        Menu {
            Button {
                guard courseHandicapAvailable else { return }
                Haptics.fire(.light)
                let next: HandicapEntryFormat = handicapEntryFormat == .courseHandicap ? .strokes : .courseHandicap
                handicapEntryFormat = next
                onEntryFormatChanged(next)
            } label: {
                Label(
                    "Course Handicap",
                    systemImage: handicapEntryFormat == .courseHandicap ? "checkmark.circle.fill" : "circle"
                )
                Text(courseHandicapMenuSubtitle)
            }
            .menuActionDismissBehavior(.disabled)
            .disabled(!courseHandicapAvailable)

            Button {
                Haptics.fire(.light)
                let next: HandicapNormalizationMode = handicapNormalizationMode == .off
                    ? (competitionScope == .matchup ? .matchup : .field)
                    : .off
                handicapNormalizationMode = next
                onNormalizationModeChanged(next)
            } label: {
                Label(
                    "Normalize Handicaps",
                    systemImage: handicapNormalizationMode == .off ? "circle" : "checkmark.circle.fill"
                )
                Text(normalizeHandicapsMenuSubtitle)
            }
            .menuActionDismissBehavior(.disabled)

            Menu {
                Button {
                    Haptics.fire(.light)
                    handicapStrokeBasis = nil
                    onStrokeBasisChanged(nil)
                } label: {
                    HStack {
                        Text("Auto")
                        if handicapStrokeBasis == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                ForEach(SeriesHandicapStrokeBasis.allCases, id: \.self) { basis in
                    Button {
                        Haptics.fire(.light)
                        handicapStrokeBasis = basis
                        onStrokeBasisChanged(basis)
                    } label: {
                        HStack {
                            Text(basis.displayName)
                            if handicapStrokeBasis == basis {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text("Hole Basis")
                Text(handicapStrokeBasisDescription)
            }
            .menuActionDismissBehavior(.disabled)
        } label: {
            Icon(name: "f141", size: 20, weight: .solid)
                .foregroundStyle(Color.charcoal)
                .frame(width: 40, height: 40)
                .glassCardEffect(cornerRadius: 20, tint: palette.whiteGlassButtonColor, shadowOpacity: 0)
                .whiteGlassCardShadow(color: palette.shadowColor)
                .accessibilityLabel("Handicap options")
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var courseHandicapMenuSubtitle: String {
        if let courseHandicapSubtitle {
            return courseHandicapSubtitle
        }
        return courseHandicapAvailable
            ? "Convert index entries using the selected tee rating and slope"
            : "Select a course and tee with rating/slope to use index entries"
    }

    private var normalizeHandicapsMenuSubtitle: String {
        competitionScope == .matchup
            ? "Play each matchup from the lowest handicap in that pairing"
            : "Play the field from the lowest handicap"
    }

    private var handicapStrokeBasisDisplay: String {
        handicapStrokeBasis?.displayName ?? "Auto"
    }

    private var handicapStrokeBasisDescription: String {
        if let resolvedAutoBasis, handicapStrokeBasis == nil {
            return "Auto currently uses \(resolvedAutoBasis.displayName)"
        }
        if handicapStrokeBasis == nil {
            return "Auto - infer 9-hole or 18-hole from the round"
        }
        return "\(handicapStrokeBasisDisplay) values"
    }
}

#Preview("Primary Dark") {
    HStack {
        NavButton(icon: "f00d")
        NavButton(icon: "f053")
        Spacer()
        NavButton(icon: "f00c")
    }
    .alignTop()
    .padding(20)
    .background(Color.backgroundPrimary)
    .colorScheme(.dark)
}

#Preview("Secondary Light") {
    HStack {
        NavButton(icon: "f00d", theme: .secondary)
        NavButton(icon: "f053", theme: .secondary)
        Spacer()
        NavButton(icon: "f00c", theme: .secondary)
    }
    .alignTop()
    .padding(20)
    .background(Color.backgroundSecondary)
    .colorScheme(.light)
}

#Preview("Secondary Dark") {
    HStack {
        NavButton(icon: "f00d", theme: .secondary)
        NavButton(icon: "f053", theme: .secondary)
        Spacer()
        NavButton(icon: "f00c", theme: .secondary)
    }
    .alignTop()
    .padding(20)
    .background(Color.backgroundSecondary)
    .colorScheme(.dark)
}

#Preview("Tile Light") {
    HackersCard(
        icon: "e1d8",
        title: "Notes",
        headerStyle: .prominent,
        callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
        content: { EmptyView() }
    )
    .alignTop()
    .padding(20)
    .background(Color.cardPrimary)
    .colorScheme(.light)
}

#Preview("Tile Dark") {
    HackersCard(
        icon: "e1d8",
        title: "Notes",
        headerStyle: .prominent,
        callToAction: { NavButton(icon: "2b", size: 15, weight: .solid) },
        content: { EmptyView() }
    )
    .alignTop()
    .padding(20)
    .background(Color.cardPrimary)
    .colorScheme(.dark)
}
