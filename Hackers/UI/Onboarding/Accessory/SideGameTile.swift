//
//  SideGameTile.swift
//  Hackers
//
//  Created by Kyle Beard on 6/20/23.
//

import SwiftUI

struct SideGameTile: View, OnSelectable {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var game: SideGame
    var isSelected: Bool = false
    var canPlay: Bool = false
    
    var onTap: OnTap?
    var onTapAsync: OnTapAync?
    var onItem: OnItem?
    var onItemAsync: OnItemAsync?
    
    /// Icon foreground
    var tintColor: Color {
        if isSelected {
            if game.underConstruction { return Color.systemHackersYellow }
            if !canPlay { return Color.systemError }
            return Color.systemHackersPurple
        } else {
            return Color.systemBlack
        }
        
//        isSelected ? Color.systemHackersPurple : Color.systemBlack
        
//        if game.underConstruction { return Color.systemHackersYellow }
//        return canPlay
//        ? isSelected
//        ? Color.systemHackersPurple
//        : Color.systemBlack
//        : Color.systemError
    }
    
    /// Icon background
    var fillColor: Color {
        if isSelected {
            if game.underConstruction { return Color.systemHackersYellow.opacity(colorScheme.translucent) }
            if !canPlay { return Color.systemError.opacity(colorScheme.translucent) }
            return Color.systemHackersPurple.opacity(colorScheme.translucent)
        } else {
            return Color.systemGray6
        }
        
//        isSelected ? Color.systemHackersPurple.opacity(colorScheme.translucent) : Color.systemGray6
        
//        if game.underConstruction { return Color.systemHackersYellow.opacity(colorScheme.translucent) }
//        return canPlay
//        ? isSelected
//        ? Color.systemHackersPurple.opacity(colorScheme.translucent)
//        : Color.systemGray6
//        : Color.systemError.opacity(colorScheme.translucent)
    }
    
    /// Game label
    var gameTintColor: Color {
        if isSelected {
            if game.underConstruction { return Color.systemHackersYellow }
            if !canPlay { return Color.systemError }
            return Color.systemHackersPurple
        } else {
            return Color.systemBlack
        }
        
//        isSelected ? Color.systemHackersPurple : Color.systemBlack
        
//        if game.underConstruction { return Color.systemHackersYellow }
//        return canPlay
//        ? isSelected
//        ? Color.systemHackersPurple
//        : Color.systemBlack
//        : Color.systemError
    }
    
    /// Chip foreground
    var playerTintColor: Color {
        canPlay
        ? isSelected
        ? Color.systemHackersPurple
        : Color.systemGray
        : Color.systemError
    }
    
    /// Chip background
    var playerFillColor: Color {
        canPlay
        ? isSelected
        ? Color.systemHackersPurple.opacity(colorScheme.translucent)
        : Color.systemGray6
        : Color.systemError.opacity(colorScheme.translucent)
    }
    
    private var borderColor: Color {
        //isSelected ? Color.systemHackersPurple : colorScheme.lightGray,
        if isSelected {
            if game.underConstruction { return Color.systemHackersYellow }
            if !canPlay { return Color.systemError }
            return Color.systemHackersPurple
        } else {
            return colorScheme.lightGray
        }
    }
    
    var body: some View {
        Button(action: onButtonPress) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(fillColor)
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: game.icon.unicode,
                        style: .regular,
                        size: 24,
                        color: tintColor
                    )
                }
                
                VStack(spacing: 4) {
                    HStack {
                        Text(game.name)
                            .foregroundColor(gameTintColor)
                            .font(.dmSans, size: 20, weight: .bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        Spacer(minLength: 10)
                        
                        if game.underConstruction {
                            Text("Coming soon")
                                .foregroundColor(Color.systemHackersYellow)
                                .font(.dmSans, size: 13, weight: .bold)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(Color.systemHackersYellow.opacity(colorScheme.translucent))
                                .cornerRadius(4)
                        } else {
                            HStack(spacing: 4) {
                                Text(game.playerLabel)
                                Image(systemName: "figure.golf")
                                    .font(.dmSans, size: 10, weight: .bold)
                            }
                            .foregroundColor(playerTintColor)
                            .font(.dmSans, size: 13, weight: .bold)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(playerFillColor)
                            .cornerRadius(4)
                        }
                    }

                    Text(game.description)
                        .foregroundColor(Color.systemGray)
                        .font(.dmSans, size: 13, weight: .medium)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .alignLeading()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color.systemCard
//                canPlay && !game.underConstruction
//                ? Color.systemCard
//                : Color.systemGray6.opacity(colorScheme.isLight ? 0.5 : 1.0)
            )
            .border(borderColor,  width: isSelected ? 6 : 3, cornerRadius: 12)
            .cornerRadius(12)
            .disabled(!canPlay || game.underConstruction)
        }
    }
    
    private func onButtonPress() {
//        if !canPlay || game.underConstruction {
//            Haptics.fire(.error)
//        } else {
//            triggerOnTap()
//            Haptics.fire(.light)
//        }
        triggerOnTap()
        Haptics.fire(.light)
    }
}

struct SideGameTile_Previews: PreviewProvider {
    static var appSession: AppSession = AppSession()
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                Group {
                    Text("Fun & Noteworthy")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans, size: 17, weight: .bold)
                        .alignLeading()
                    
                    SideGameTile(game: .medalPlay)
                    SideGameTile(game: .stableford)
                    SideGameTile(game: .bestBall)
                    SideGameTile(game: .vegas)
                    SideGameTile(game: .bingoBangoBongo)
                }
                
                Group {
                    Text("Made by Hackers")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans, size: 17, weight: .bold)
                        .alignLeading()
                    
                    SideGameTile(game: .cardsOfChaos)
                    SideGameTile(game: .monkeyInTheMiddle)
                    SideGameTile(game: .fibonacci)
                    SideGameTile(game: .football)
                    SideGameTile(game: .jackpot)
                    SideGameTile(game: .hotPotato)
                    SideGameTile(game: .survivor)
                }
                Group {
                    Text("High Stakes")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans, size: 17, weight: .bold)
                        .alignLeading()
                    
                    SideGameTile(game: .banker)
                    SideGameTile(game: .hammer)
                    SideGameTile(game: .wolfHammer)
                }
            }
            .padding(.horizontal, 20)
        }
        .environmentObject(appSession)
        .onAppear() {
            appSession.players = [kPlayerKyle, kPlayerSarah]
        }
        .holisticPreview()
    }
}
