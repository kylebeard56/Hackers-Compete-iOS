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
    
    private var titleText: String {
        switch (showTeam, showTeeGroup) {
        case (true, true):
            return "Setup Incomplete"
        case (true, false):
            return "Teams Incomplete"
        case (false, true):
            return "Tee Groups Incomplete"
        default:
            return "Setup Incomplete"
        }
    }

    private var subtitleText: String {
        switch (showTeam, showTeeGroup) {
        case (true, true):
            return "One or more players are missing team and tee group assignments. Please finish setup before starting your round."
        case (true, false):
            return "One or more players haven’t been assigned to a team. Assign everyone to ensure balanced scoring."
        case (false, true):
            return "Some players haven’t been assigned to a tee group. Assign everyone to avoid confusion on the course."
        default:
            return "Please review your round setup to ensure all players are assigned to teams and tee groups and try again."
        }
    }
    
    private let iconSize: CGFloat = 56
    
    var body: some View {
        VStack(spacing: 16) {
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
                .fontStyle(.poppins, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            Text(subtitleText)
                .fontStyle(.poppins, size: 17, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
                .alignCenter()

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
