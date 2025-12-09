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
        Text("Game format".uppercased())
            .fontStyle(.poppins, size: 20, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .alignCenter()
        
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentGreen)
                    .frame(width: 80, height: 80)
                
                Icon(name: "f450", size: 40, weight: .regular)
                    .foregroundStyle(.white)
            }
            
            Text(snapshot.gameFormat.type.displayName.uppercased())
                .fontStyle(.poppins, size: 17, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
        }
        
        VStack(spacing: 16) {
            Toggle(isOn: $handicapsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Handicaps".uppercased())
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Allocate strokes for each player")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            })
            .tint(.accentGreen)
            .tileEffect(for: palette)
            .onChange(of: handicapsEnabled) {
                Task {
                    await roundService.toggleHandicaps(handicapsEnabled)
                }
            }
            
            Toggle(isOn: snapshot.requiresTeams ? .true : $teamsEnabled, label: {
                VStack(spacing: 4) {
                    Text("Teams".uppercased())
                        .fontStyle(.poppins, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()
                    
                    Text("Organize and compete as groups")
                        .fontStyle(.poppins, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            })
            .tint(.accentGreen)
            .tileEffect(for: palette)
            .onChange(of: teamsEnabled) {
                Task {
                    await roundService.toggleTeams(teamsEnabled)
                }
            }
        }
    }
}
