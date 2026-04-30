//
//  RoundActivationErrorView.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/26.
//

import SwiftUI

struct RoundActivationErrorView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
//    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    private var showTeam: Bool { roundSession.roundActivationErrors.contains(.playerMissingFromTeam) }
    private var showTeeGroup: Bool { roundSession.roundActivationErrors.contains(.playerMissingFromTeeGroup) }
    private var showScoringGroups: Bool { roundSession.roundActivationErrors.contains(.scoringGroupsIncomplete) }
    private var showScoringGroupInvalidRefs: Bool { roundSession.roundActivationErrors.contains(.scoringGroupsInvalidReferences) }
    private var showMatchups: Bool { roundSession.roundActivationErrors.contains(.matchupsIncomplete) }
    private var showMatchupInvalidRefs: Bool { roundSession.roundActivationErrors.contains(.matchupInvalidReferences) }
    private var showCourseSegmentMismatch: Bool { roundSession.roundActivationErrors.contains(.courseSegmentMismatch) }
    private var showVegasConfiguration: Bool { roundSession.roundActivationErrors.contains(.vegasConfigurationInvalid) }
    private var scoreOwnerLabel: String {
        switch roundSession.snapshot.configuration.scoreOwnerScope {
        case .individual: "score groups"
        case .partnership: "partnerships"
        case .teeGroup: "score groups"
        }
    }
    
    private var titleText: String {
        if showScoringGroupInvalidRefs && !showTeam && !showTeeGroup {
            return "Score Groups Incomplete or Incompatible"
        }
        if showVegasConfiguration && !showTeam && !showTeeGroup {
            return "Vegas Setup Needed"
        }
        if showScoringGroups && !showTeam && !showTeeGroup {
            return "Setup Incomplete or Incompatible"
        }
        if showMatchupInvalidRefs && !showTeam && !showTeeGroup {
            return "Matchups Incomplete or Incompatible"
        }
        if showCourseSegmentMismatch && !showTeam && !showTeeGroup {
            return "Course Setup Needs Repair"
        }
        if showMatchups && !showTeam && !showTeeGroup {
            return "Matchups Incomplete or Incompatible"
        }
        switch (showTeam, showTeeGroup) {
        case (true, true):
            return "Setup Incomplete or Incompatible"
        case (true, false):
            return "Teams Incomplete or Incompatible"
        case (false, true):
            return "Tee Groups Incomplete or Incompatible"
        default:
            return "Setup Incomplete or Incompatible"
        }
    }

    private var subtitleText: String {
        if showScoringGroupInvalidRefs {
            return "One or more \(scoreOwnerLabel) reference players who are no longer grouped together correctly, or no longer match this format. Update the round setup before starting live play."
        }
        if showVegasConfiguration {
            return "Your teams have more than 2 players. Either group teams into twosomes, assign pairs, or pick which two scores count in the game configuration above."
        }
        if showScoringGroups {
            return "This format needs valid \(scoreOwnerLabel) before the round can start. Finish setup or re-sync the format so every score owner matches the round configuration."
        }
        if showMatchupInvalidRefs {
            return "One or more matchups reference teams, players, or score groups that no longer match this round. Open the Matchups tab and re-assign each pairing."
        }
        if showCourseSegmentMismatch {
            return roundSession.snapshot.primarySegmentHoleRangeMismatch?.diagnosticDetail
                ?? "The selected course holes do not match the scoring segment used for matchups and awards. Re-save the course selection before starting live play."
        }
        if showMatchups && !showTeam && !showTeeGroup {
            return "Set up at least one complete head-to-head matchup, or re-sync the format if the saved matchups no longer match this round setup."
        }
        switch (showTeam, showTeeGroup) {
        case (true, true):
            return "One or more players are missing team or tee group assignments, or the saved groups no longer match this format. Please finish setup before starting your round."
        case (true, false):
            return "One or more players haven’t been assigned to a team, or the saved teams no longer match this format. Assign everyone before starting."
        case (false, true):
            return "Some players haven’t been assigned to a tee group, or the saved tee groups no longer match this format. Assign everyone before starting."
        default:
            return "Please review your round setup to ensure all players are assigned to teams and tee groups and try again."
        }
    }
    
    private let iconSize: CGFloat = 48
    
    var body: some View {
        VStack(spacing: 12) {
            NavButton(
                icon: "f00d",
                color: palette.foregroundColor,
                theme: palette.theme,
                onTap: { dismiss() }
            )
            .alignTrailing()
            
            Spacer(minLength: 0)
            
            ZStack {
                Circle()
                    .fill(Color.systemOrange.opacity(colorScheme.translucent))
                    .frame(width: iconSize * 2, height: iconSize * 2)
                
                Icon(name: "f071", size: iconSize)
                    .foregroundStyle(Color.systemOrange)
            }
            
            Text(titleText)
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .alignCenter()
                .layoutPriority(2)

            Text(subtitleText)
                .fontStyle(kFontName, size: 17, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
                .lineLimit(6)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .alignCenter()
                .layoutPriority(1)

            Spacer(minLength: 0)
            
            PrimaryButton(
                title: "OK",
                labelColor: palette.backgroundColor,
                buttonColor: palette.foregroundColor,
                isDisabled: .false,
                isLoading: .false,
                onTap: { dismiss() }
            )
        }
        .padding(16)
        .background(palette.backgroundColor)
    }
}

@MainActor
private enum Mock {
    static func roundSession(_ errors: [RoundActivationError]) -> RoundSession {
        let rs = RoundSession()
        rs.roundActivationErrors = Set(errors)
        return rs
    }
    
}

#Preview("Team") {
    ZStack {
        Color.neutral6
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: .true) {
                RoundActivationErrorView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
    }
    .environmentObject(Mock.roundSession([.playerMissingFromTeam]))
}

#Preview("Tee Group") {
    ZStack {
        Color.neutral6
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: .true) {
                RoundActivationErrorView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
    }
    .environmentObject(Mock.roundSession([.playerMissingFromTeeGroup]))
}

#Preview("Both") {
    ZStack {
        Color.neutral6
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: .true) {
                RoundActivationErrorView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
    }
    .environmentObject(Mock.roundSession([.playerMissingFromTeam, .playerMissingFromTeeGroup]))
}

#Preview("Neither") {
    ZStack {
        Color.neutral6
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: .true) {
                RoundActivationErrorView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
    }
    .environmentObject(Mock.roundSession([]))
}

#Preview("Course Segment Mismatch") {
    ZStack {
        Color.neutral6
            .edgesIgnoringSafeArea(.all)
            .sheet(isPresented: .true) {
                RoundActivationErrorView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
    }
    .environmentObject(Mock.roundSession([.courseSegmentMismatch]))
}
