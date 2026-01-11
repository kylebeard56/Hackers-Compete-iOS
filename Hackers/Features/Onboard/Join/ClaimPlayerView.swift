//
//  ClaimPlayerView.swift
//  Hackers
//
//  Created by Kyle Beard on 9/18/25.
//

import SwiftUI

struct ClaimPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject var viewModel: JoinRoundViewModel
    var onConfirm: CallbackValue<RoundParticipant>? = nil
    
    @State private var showAddNew = false
    
    private var unclaimed: [RoundParticipant] { viewModel.participants.filter(\.isOffline) }
    private var claimed: [RoundParticipant] { viewModel.participants.filter(\.isOnline) }
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .sheet(isPresented: $showAddNew) {
            NewOfflinePlayerView() { player in
                print("claim new player")
                printPretty(player)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text("Claim your player")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                NavButton(icon: "f00d", onTap: { dismiss() })
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }
    
    private var footer: some View {
        VStack(spacing: 16) {
            Line()
            
            PrimaryButton(
                appearance: .fill,
                title: "Add new player",
                labelColor: palette.backgroundColor,
                buttonColor: palette.foregroundColor,
                theme: palette.theme,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                   showAddNew = true
                }
            )
            .padding(.horizontal, 16)
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                if unclaimed.isPopulated {
                    Text("\(unclaimed.count) available to claim")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(Color.accentPurple)
                        .alignLeading()
                    
                    ForEach(unclaimed.sorted { $0.alphabeticName < $1.alphabeticName }, id: \.self) { p in
                        row(for: p)
                        Line()
                    }
                }

                Spacer().frame(height: 0)
                
                if claimed.isPopulated {
                    Text("\(claimed.count) already claimed")
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                    
                    ForEach(claimed.sorted { $0.alphabeticName < $1.alphabeticName }, id: \.self) { p in
                        row(for: p)
                        Line()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func row(for participant: RoundParticipant) -> some View {
        HStack(spacing: 12) {
            Text(participant.name.fullName)
                .fontStyle(.poppins, size: 17, weight: .medium)
                .foregroundStyle(Color.foregroundPrimary)
            
            Spacer(minLength: 0)

            if participant.isOffline {
                Button {
                    Haptics.fire(.light)
                    viewModel.claimedParticipant = participant
                    dismiss()
                } label: {
                    Chip(
                        text: "Claim",
                        size: .small,
                        style: .fill,
                        foreground: Color.accentPurple,
                        background: Color.neutral6
                    )
                }
            }
        }
    }
}

@MainActor
private enum Mock {
    static func viewModel() -> JoinRoundViewModel {
        let vm = JoinRoundViewModel()
        
        let p: RoundParticipant = .init(id: "1", userID: "1", name: Name("Kyle", "Beard"), isHost: true)
        //vm.claimedParticipant = p
        
        vm.participants = [
            p,
            .init(id: "2", userID: "2", name: Name("Andrew", "McCartney")),
            .init(id: "3", userID: "3", name: Name("Greg", "Lorenz")),
            .init(id: "4", userID: nil, name: Name("Joey", "Black")),
            .init(id: "5", userID: nil, name: Name("Will", "O'Shea")),
            .init(id: "6", userID: nil, name: Name("Corey", "McCann")),
            .init(id: "7", userID: "7", name: Name("Matt", "Henry")),
            .init(id: "8", userID: "8", name: Name("Mike", "Wondrasek"))
        ]
        
        return vm
    }
    
    static let user: HackersUser = {
        return HackersUser(
            id: "1",
            players: ["p1"]
        )
    }()
    
    static let player: Player = {
        Player(
            id: "p1",
            name: Name("Kyle", "Beard"),
            rounds: [],
            handicaps: [
                .init(id: "hcp1", name: "Verdae", value: 16, isDefault: true)
            ],
            isPrimary: true
        )
    }()
}

#Preview {
    ZStack {
        Color.backgroundPrimary.sheet(isPresented: .true) {
            ClaimPlayerView(viewModel: Mock.viewModel())
                .presentationDragIndicator(.visible)
        }
    }
}
