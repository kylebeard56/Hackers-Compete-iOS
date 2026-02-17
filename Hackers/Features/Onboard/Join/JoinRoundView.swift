//
//  JoinRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/28/25.
//

import SwiftUI

struct JoinRoundView: View, Loggable {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: JoinRoundViewModel
    
    var shareCode: String = ""
    var onDismiss: Callback? = nil
    
    @State private var isRootView: Bool = false
    @State private var showPlayerSelector = false
    @State private var showAuthTile = false
    
    private var courseSegment: CourseSegment? { viewModel.round?.configuration.courses.first }
    private var courseName: String { courseSegment?.courseInfo.name ?? "Unknown" }
    private var holeCount: Int { courseSegment?.holeRange.count ?? 0 }
    private var holeSegmentName: String { courseSegment?.holeSegment.title ?? "\(holeCount)" }
    private var playerCount: Int { viewModel.round?.players.count ?? -1 }
    private var gameFormat: String { viewModel.round?.configuration.primaryFormat.type.displayName ?? "Game format" }
    private var host: RoundParticipant? { viewModel.participants.first(where: \.isHost) }
    private var useHandicaps: Bool { viewModel.round?.configuration.useHandicaps ?? false }
    private var requiresTeams: Bool { viewModel.round?.configuration.primaryFormat.configuration.requiresTeams ?? false }
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showPlayerSelector) {
            ClaimPlayerView(viewModel: viewModel)
                .environmentObject(appSession)
        }
        .sheet(isPresented: $showAuthTile) {
            AuthTile(onAuth: { newlyCreated in
                await appSession.syncUserState()
                
                if newlyCreated {
                    // First-time user -> link the player they claimed
                    if viewModel.newClaimedPlayer.exists {
                        await viewModel.claimNewPlayerAndEnterRound()
                    } else {
                        await viewModel.claimOfflineParticipant()
                    }
                } else {
                    // Existing user -> override their claim with their primary player
                    await viewModel.overrideClaimWithPrimaryPlayer()
                }
                showAuthTile = false
            }, onContinueAsGuest: {
                if viewModel.newClaimedPlayer.exists {
                    await viewModel.claimNewPlayerAndEnterRound()
                } else {
                    await viewModel.continueAsGuest()
                }
                showAuthTile = false
            })
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
    }
    
    var header: some View {
        ZStack {
            if !isRootView {
                NavButton(icon: "f053", onTap: { dismiss() })
                    .alignLeading()
            }
            
            Text("Join round?")
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            NavButton(icon: "f00d", onTap: {
                if isRootView {
                    dismiss()
                } else {
                    onDismiss?()
                }
            })
            .alignTrailing()
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
    
    var footer: some View {
        VStack(spacing: 16) {
            Line()
            
            PrimaryButton(
                appearance: .fill,
                title: "Join",
                labelColor: palette.backgroundColor,
                buttonColor: palette.foregroundColor,
                iconSize: 24,
                isDisabled: .constant(viewModel.claimedParticipant == nil),
                isLoading: .false,
                onTapAsync: {
                    if await AppData.shared.user.doesNotExist {
                        // 1. User claimed player, prompt to auth before continuing to claim or as guest.
                        showAuthTile = true
                    } else if viewModel.isPlayerLocked {
                        // 2. User is already in round, continue as-is
                        await viewModel.enterRoundIfAlreadyJoined()
                    } else {
                        // 3. User selected participant to claim, map to user account and continue.
                        await viewModel.claimOfflineParticipant()
                    }
                }
            )
            .padding(.horizontal, 16)
            
            PrimaryButton(
                appearance: .fill,
                title: "Spectate",
                labelColor: palette.foregroundColor,
                buttonColor: Color.neutral6,
                iconSize: 24,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    addBreadcrumb(message: "fake door: join round as spectator")
                    // [FUTURE] TODO: Create a view that acts as a waiting room for the round to start. APN too.
                }
            )
            .padding(.horizontal, 16)
        }
    }
    
    // [FUTURE] TODO: Add skeleton here when we implement loading from injected share code vs. find round pre-req.
    var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Spacer().frame(height: 0)
                
                Text("Round details")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                roundInformation
                    .outlineEffect(for: palette)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Pick your player")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Spacer(minLength: 0)
                    
                    if viewModel.claimedParticipant == nil {
                        Chip.required
                    } else {
                        Chip.requiredConfirmation
                    }
                }
                
                playerSelectionDropdown
                
                if viewModel.isPlayerLocked {
                    Text("Your player account has been linked to this round.")
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                    
                    // Note: I don't think we want users to be able to logout if they're player is in the round.
//                    Button {
//                        Haptics.fire(.light)
//                        softLogout()
//                    } label: {
//                        Text("Don't want this player? Logout to unset.")
//                            .fontStyle(kFontName, size: 14, weight: .semibold)
//                            .foregroundStyle(Color.accentGreen)
//                            .alignLeading()
//                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
    
//    private func softLogout() {
//        do {
//            try AuthService.shared.logout()
//            appSession.reset(routeToAuth: false)
//            viewModel.claimedParticipant = nil
//            viewModel.isPlayerLocked = false
//        } catch let error {
//            addBreadcrumb(
//                level: .warning,
//                message: "Failed to logout to change user while joining round",
//                error: error
//            )
//        }
//    }
    
    private var roundInformation: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Course")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(courseName)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Host")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(viewModel.hostName)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)
            
            HStack(spacing: 16) {
                Text("Players")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text("\(playerCount)")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Holes")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(holeSegmentName)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Game")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(gameFormat)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Teams")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(requiresTeams ? "Yes" : "No")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Strokes")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(useHandicaps ? "Yes" : "No")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)
        }
    }
    
    private func stackedSubtitle(value: String, label: String) -> some View {
        StackedSubtitle(
            value: value,
            label: label,
            tint: .accentPurple,
            subTint: .accentPurple
        )
        .padding(10)
        .background(.accentPurple.opacity(colorScheme.translucent))
        .cornerRadius(radius: 10)
    }
    
    @ViewBuilder
    private var playerSelectionDropdown: some View {
        Button(action: {
            Haptics.fire(.light)
            showPlayerSelector = true
        }) {
            HStack {
                if let participant = viewModel.claimedParticipant {
                    Text(participant.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.foregroundPrimary)
                } else {
                    Text("Select your player")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                
                Spacer()
                
                if !viewModel.isPlayerLocked {
                    Icon(name: "f078", size: 12, weight: .solid)
                        .foregroundStyle(Color.neutral3)
                } else {
                    Icon(name: "f00c", size: 12, weight: .solid)
                        .foregroundStyle(Color.accentGreen)
                }
            }
            .padding(16)
            .border(Color.neutral5, width: 1.5, cornerRadius: 10)
        }
        .disabled(viewModel.isPlayerLocked)
    }
}

@MainActor
private struct PreviewBridge {
    static var viewModel: JoinRoundViewModel = {
        let v = JoinRoundViewModel()
        v.participants = [
            MockParticipants.participant1,
            MockParticipants.participant2,
            MockParticipants.participant3,
            MockParticipants.participant4
        ]
        v.round = MockRound.strokePlay
        v.round?.configuration.courses = [CourseSegment(
            courseInfo: .init(
                course: .init(from: MockCourses.mountainPark),
                for: .init(range: .init(startHole: 1, endHole: 18))),
            holeRange: .init(startHole: 1, endHole: 18),
            defaultTee: nil
        )]
        return v
    }()
}

#Preview {
    ZStack {
        Color.backgroundPrimary
            .ignoresSafeArea()
            .sheet(isPresented: .true) {
                JoinRoundView(viewModel: PreviewBridge.viewModel)
                    .environmentObject(AppSession())
                    .presentationDragIndicator(.visible)
        }
    }
}
