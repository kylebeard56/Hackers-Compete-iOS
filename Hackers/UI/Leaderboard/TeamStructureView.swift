//
//  TeamStructureView.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import SwiftUI

enum TeamName: String {
    case one = "Team One"
    case two = "Team Two"
}

struct TeamStructureView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: RoundViewModel
    
    @State private var players: [Player] = []
    
    @State private var cannotSave: Bool = false
    
    var body: some View {
        bodyView
            .padding(.bottom, 10)
            .padding(.horizontal, 20)
            .background(Color.systemViewBackground)
    }
    
    var bodyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Manage teams")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.bottom, 10)
            
            content
            
            Spacer(minLength: 0)
            
            SmallButton(title: "Clear teams", isDisabled: .false, isLoading: .false)
                .onTap {
                    for i in 0..<players.count { players[i].team = "" }
                    viewModel.players = players
                    Haptics.fire(.light)
                }
            
            BigButton(title: "Save and play", isDisabled: $cannotSave, isLoading: .false)
                .onTap {
                    viewModel.players = self.players
                    Haptics.fire(.light)
                    dismiss()
                }
        }
        .onAppear() { players = viewModel.players }
        .onChange(of: viewModel.players, perform: { p in players = p })
        .onChange(of: players, perform: { p in
            let one = players.filter({ $0.team == TeamName.one.rawValue }).count
            let two = players.filter({ $0.team == TeamName.two.rawValue }).count
            
            /// Allow players to make teams of 2v2 or 1v3
            switch (one > 0, two > 0) {
            case (true, true):     self.cannotSave = (one + two != players.count)
            case (false, false):   self.cannotSave = false
            default:               self.cannotSave = true
            }
        })
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Text("Set pairings for the leaderboard and any active side games.")
                .foregroundColor(Color.systemBlack)
                .font(.dmSans(size: 17, weight: .regular))
                .alignLeading()
            
            InfoBanner(
                text: "Changes will adjust scoring for past, present, and future holes.",
                foregroundColor: Color.systemHackersGreen,
                backgroundColor: Color.systemHackersGreen.opacity(colorScheme.translucent)
            )
                
            HStack(spacing: 0) {
                Text("Team One")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Text("Players")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                
                Text("Team Two")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignTrailing()
            }
            
            ForEach(0..<players.count, id: \.self) { i in
                let p = players[i]
                HStack(spacing: 0) {
                    button(for: i, team: TeamName.one.rawValue)
                        .alignLeading()
                    Text("\(p.name)")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(p.color.value)
                        .alignCenter()
                    button(for: i, team: TeamName.two.rawValue)
                        .alignTrailing()
                }
            }
        }
    }
    
    @ViewBuilder private func button(for i: Int, team: String) -> some View {
        let isSelected = players[i].team == team
        let color = players[i].color.value
        
        Button(action: {
            players[i].team = isSelected ? "" : team
            Haptics.fire(.light)
        }) {
            if isSelected {
                ZStack {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(color)
                    Circle()
                        .fill(color.opacity(0.125))
                        .frame(width: 40, height: 40)
                }
            } else {
                Circle()
                    .stroke(Color.systemGray5, lineWidth: 2)
                    .frame(width: 40, height: 40)
            }
        }
    }
    
//    private func add(_ player: Player, to team: TeamName) {
//        if let i = viewModel.teams.firstIndex(where: { $0.name == team.rawValue }) {
//            var team = viewModel.teams[i]
//            team.players.toggle(player.id)
//            viewModel.teams[i] = team
//        }
//    }
    
//    private func isPlayer(_ player: Player, on team: TeamName) -> Bool {
//        guard let team = viewModel.teams.first(where: { $0.name == team.rawValue }) else { return false}
//        return team.players.contains(player.id)
//    }
}

struct TeamStructureView_Previews: PreviewProvider {
    static var vm = RoundViewModel()
    static let players: [Player] = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
    
    static var previews: some View {
        TeamStructureView(viewModel: vm)
            .onAppear() { vm.players = players }
            .holisticPreview()
    }
}
