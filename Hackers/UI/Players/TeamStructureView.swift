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
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 16)
            
            content
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                Button(action: {
                    for i in 0..<players.count { players[i].team = "" }
                    viewModel.players = self.players
                    Haptics.fire(.light)
                }) {
                    Text("Reset")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
                Button(action: {
                    print("SET TEAMS")
                    printPretty(self.players)
                    viewModel.players = self.players
                    Haptics.fire(.light)
                    dismiss()
                }) {
                    Text("Set teams")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemWhite)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemBlack)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.systemViewBackground)
        .padding(.bottom, UIScreen.isSmall ? 8 : 0)
        .onAppear() {
            self.players = viewModel.players
        }
    }
    
    private var header: some View {
        VStack {
            HStack {
                Text("Setup teams")
                    .font(.fugazOne(size: 32))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }
            
            Text("Set your lineup for who plays together:")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    private var content: some View {
        VStack(spacing: 32) {
            HStack(spacing: 12) {
                VStack(spacing: 32) {
                    Text("Team One")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
                .alignCenter()
                
                VStack(spacing: 32) {
                    Text("Players")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
                .alignCenter()
                
                VStack(spacing: 32) {
                    Text("Team Two")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
                .alignCenter()
            }
            
            ForEach(0..<players.count, id: \.self) { i in
                HStack(spacing: 12) {
                    Button(action: {
                        players[i].team = TeamName.one.rawValue
                        Haptics.fire(.light)
                    }) {
                        if players[i].team == TeamName.one.rawValue {
                            ZStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.systemHackersGreen)
                                Circle()
                                    .fill(Color.systemHackersGreen.opacity(0.125))
                                    .frame(width: 40, height: 40)
                                    .alignCenter()
                            }
                        } else {
                            Circle()
                                .stroke(Color.systemGray4, lineWidth: 2)
                                .frame(width: 40, height: 40)
                                .alignCenter()
                        }
                    }
                    
                    Text(players[i].name)
                        .font(.dmSans(size: 22, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .alignCenter()
                    
                    Button(action: {
                        players[i].team = TeamName.two.rawValue
                        Haptics.fire(.light)
                    }) {
                        if players[i].team == TeamName.two.rawValue {
                            ZStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.systemHackersGreen)
                                Circle()
                                    .fill(Color.systemHackersGreen.opacity(0.125))
                                    .frame(width: 40, height: 40)
                                    .alignCenter()
                            }
                        } else {
                            Circle()
                                .stroke(Color.systemGray4, lineWidth: 2)
                                .frame(width: 40, height: 40)
                                .alignCenter()
                        }
                    }
                }
            }
        }
        .padding(16)
        .border(Color.systemGray6, width: 2, cornerRadius: 8)
        .alignTop()
    }
    
    private func add(_ player: Player, to team: TeamName) {
        if let i = viewModel.teams.firstIndex(where: { $0.name == team.rawValue }) {
            var team = viewModel.teams[i]
            team.players.toggle(player.id)
            viewModel.teams[i] = team
        }
    }
    
    private func isPlayer(_ player: Player, on team: TeamName) -> Bool {
        guard let team = viewModel.teams.first(where: { $0.name == team.rawValue }) else { return false}
        return team.players.contains(player.id)
    }
}

struct TeamStructureView_Previews: PreviewProvider {
    static var view: some View {
        TeamStructureView(viewModel: RoundViewModel())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
