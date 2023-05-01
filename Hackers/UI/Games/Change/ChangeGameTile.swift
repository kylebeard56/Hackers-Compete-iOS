//
//  ChangeGameTile.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import SwiftUI

struct ChangeGameTile: View, Tappable {
    var game: HackersGame
    var selected: Bool = false
    
    // Conform to Tappable
    var onTap: (() -> Void)?
    var onTapTask: (() async -> Void)?
    
    var body: some View {
        Button(action: {
            triggerOnTap()
            Task { await triggerTaskOnTap() }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersGreen.opacity(0.125))
                        .frame(width: 32, height: 32)
                    AwesomeImage(rawIcon: game.icon.unicode, style: .light, size: 16, color: .systemHackersGreen)
                }
                
                Text(game.name)
                    .font(.fugazOne(size: 15))
                    .foregroundColor(Color.systemHackersGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .alignCenter()
                
                Text(game.description)
                    .font(.dmSans(size: 10, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
            }
            .padding(16)
            .background(Color.systemCard)
            .border(selected ? Color.systemBlack : Color.systemGray5, width: selected ? 4 : 2, cornerRadius: 16)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 4)
        }
    }
}

struct ChangeGameTile_Previews: PreviewProvider {
    static var view: some View {
        HStack(spacing: 12) {
            ChangeGameTile(game: .traditional, selected: false)
            ChangeGameTile(game: .chaos, selected: false)
        }
        .padding(16)
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
