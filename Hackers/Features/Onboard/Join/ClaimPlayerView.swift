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
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    Text("Players")
                        .fontStyle(.poppins, size: 24, weight: .semibold)
                        .foregroundStyle(Color.systemBlack)
                        .alignLeading()
                    
                    Spacer(minLength: 0)
                    
                    NavButton(icon: "f00d", onTap: { dismiss() })
                }
                
                Text("\(viewModel.participants.count) total")
                    .fontStyle(.poppins, size: 17, weight: .medium)
                    .foregroundStyle(Color.hackersGray)
                    .alignLeading()
            }
            
            ForEach(viewModel.participants, id: \.self) { p in
                HStack {
                    Text(p.name.fullName)
                        .fontStyle(.poppins, size: 17, weight: .medium)
                        .foregroundStyle(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
                    if let userID = p.userID {
                        Chip(
                            text: "Claimed", // TODO: Show this as "You"
                            size: .small,
                            style: .fill,
                            foreground: Color.hackersPurple,
                            background: Color.hackersPurple.opacity(colorScheme.translucent)
                        )
                    } else if viewModel.claimedParticipant == nil {
                        Icon(name: "f058", size: 17, weight: .solid)
                            .foregroundStyle(Color.systemBlack)
                    } else {
                        Circle()
                            .stroke(Color.hackersGray5, lineWidth: 2)
                            .frame(width: 17, height: 17)
                    }
                }
                
                Line()
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}

@MainActor
private enum Mock {
    static func viewModel() -> JoinRoundViewModel {
        let vm = JoinRoundViewModel()
        
        let p: RoundParticipant = .init(id: "1", userID: "1", name: Name("Kyle", "Beard"), isHost: true)
        vm.claimedParticipant = p
        
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
            players: [
                PlayerProfile(
                    id: "1",
                    name: Name("Kyle", "Beard"),
                    rounds: [],
                    handicaps: [
                        .init(id: "hcp1", name: "Verdae", value: 16, isDefault: true)
                    ],
                    isPrimary: true
                )
            ]
        )
    }()
}

#Preview {
    ClaimPlayerView(viewModel: Mock.viewModel())
}
