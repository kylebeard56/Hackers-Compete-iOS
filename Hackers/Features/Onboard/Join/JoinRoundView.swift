//
//  JoinRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/28/25.
//

import SwiftUI

struct JoinRoundView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var viewModel: JoinRoundViewModel
    
    @State private var showPlayerSelector = false
    
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
        }
        .task {
            
        }
    }
    
    var header: some View {
        ZStack {
            NavButton(icon: "f053", onTap: { dismiss() })
                .alignLeading()
            
            Text("Join round?")
                .fontStyle(.poppins, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
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
                labelColor: .white,
                buttonColor: .black,
                iconSize: 24,
                isDisabled: .constant(viewModel.claimedParticipant == nil),
                isLoading: .false,
                onTap: {
                    ///
                    ///
                    print("todo: update this round with participant and then go")
                }
            )
            .padding(.horizontal, 16)
        }
    }
    
    var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Round details")
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()
                
                roundInformation
                    .outlineEffect(for: palette)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Pick your player")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
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
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
    
    private var roundInformation: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("Course")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(courseName)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(.poppins, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Players")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text("\(playerCount)")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(.poppins, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Holes")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(holeSegmentName)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(.poppins, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Game")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(gameFormat)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(.poppins, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Teams")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(requiresTeams ? "Yes" : "No")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(.poppins, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Strokes")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(useHandicaps ? "Yes" : "No")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(.poppins, size: 15, weight: .medium)
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
                        .fontStyle(.poppins, size: 15, weight: .regular)
                        .foregroundStyle(Color.foregroundPrimary)
                } else {
                    Text("Select your player")
                        .fontStyle(.poppins, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                
                Spacer()
                
                if !viewModel.playerSelectionDisabled {
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
        .disabled(viewModel.playerSelectionDisabled)
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
                    .presentationDragIndicator(.visible)
        }
    }
}
