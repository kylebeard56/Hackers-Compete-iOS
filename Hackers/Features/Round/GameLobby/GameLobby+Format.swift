//
//  GameLobby+Format.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/25.
//

import SwiftUI

extension GameLobby {
    @ViewBuilder
    var gameFormatSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 14) {
                Text("Game Format".uppercased())
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()
                
                VStack(spacing: 12) {
//                    ZStack {
//                        Circle()
//                            .fill(Color.accentGreen.opacity(colorScheme.translucent))
//                        Icon(name: snapshot.gameFormat.type.icon, size: 40, weight: .regular)
//                            .foregroundStyle(Color.accentGreen)
//                    }
//                    .frame(width: 80, height: 80)
                    
                    ZStack {
                        Circle()
                            .fill(Color.accentGreen.opacity(colorScheme.translucent))
                            .frame(width: 120, height: 120)
                        Icon(name: snapshot.activeTemplate.icon, size: 48, weight: .regular)
                            .foregroundStyle(Color.accentGreen)
                            .padding(24)
                    }
                    .frame(width: 120, height: 120)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                    
                    Text(snapshot.activeTemplate.name.uppercased())
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                    
                    Text(snapshot.activeTemplate.description)
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .multilineTextAlignment(.center)
                }

                if formatCardTemplateSupportsBestN {
                    rankSelectionBlock
                }
                
                Button {
                    Haptics.fire(.light)
                    showFormatSelectionView = true
                } label: {
                    Text("Change format")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                        .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
                }
                .padding(.top, 16)
            }
            .padding(16)
            .glassCardEffect()
            
//            GlassButton(
//                title: "Change format",
//                height: 40,
//                fillWidth: false,
//                fontSize: 15,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: {
//                    // Fake door for MVP expansion testing
//                }
//            )
        }
    }

    private var formatCardTemplateSupportsBestN: Bool {
        snapshot.activeTemplate.pipeline.contains { stage in
            if case .select = stage { return true }
            return false
        }
    }

    @ViewBuilder
    private var rankSelectionBlock: some View {
        let ranks = formatCardBestNRanksFromTemplate
        let current = formatCardBestNSelected
        let displayName = formatCardIsBestWorst ? "Best / Worst" : "Best \(current)"

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Scoring")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                Text("Select which best scores count")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .alignLeading()
            }

            Spacer(minLength: 0)

            Menu {
                ForEach(ranks, id: \.self) { n in
                    Button {
                        Haptics.fire(.light)
                        Task { await roundSession.setBestN(n) }
                    } label: {
                        HStack {
                            Text("Best \(n)")
                            if !formatCardIsBestWorst && n == current {
                                Icon(name: "f00c", size: 12, weight: .solid)
                            }
                        }
                    }
                }
                Button {
                    Haptics.fire(.light)
                    Task { await roundSession.setBestWorst() }
                } label: {
                    HStack {
                        Text("Best / Worst")
                        if formatCardIsBestWorst {
                            Icon(name: "f00c", size: 12, weight: .solid)
                        }
                    }
                }
                Button {
                    Haptics.fire(.error)
                } label: {
                    Text("Custom")
                }
            } label: {
                Text(displayName)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(Color.charcoal)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
                    .shadow(color: palette.shadowColor, radius: 12, x: 0, y: 0)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(palette.borderColor, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.neutral6.opacity(0.3)))
        )
        .padding(.top, 8)
    }

    /// Available rank options (Best 1, Best 2, etc.) for formats with configurable best N.
    /// For best ball, derives from team size (1...max) so user can choose Best 1, Best 2, etc.
    private var formatCardBestNRanksFromTemplate: [Int] {
        let template = snapshot.activeTemplate
        guard template.pipeline.contains(where: { if case .select = $0 { return true }; return false }) else { return [] }
        if let maxSize = template.requirements.teamSize?.maxTeamSize, maxSize > 0 {
            return Array(1...maxSize)
        }
        for stage in template.pipeline {
            if case .select(let sel) = stage, let ranks = sel.includeRanks, !ranks.isEmpty {
                return ranks.sorted()
            }
        }
        return []
    }

    private var formatCardBestNSelected: Int {
        snapshot.configuration.bestNSelected
            ?? formatCardBestNRanksFromTemplate.first
            ?? 1
    }

    private var formatCardIsBestWorst: Bool {
        snapshot.configuration.bestWorstEnabled ?? false
    }
}
