//
//  GameCardHeader.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import SwiftUI

struct GameCardHeader: View {
    var game: HackersGame
    var condense: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            if UIScreen.isSmall || condense {
                inlineHeader
            } else {
                stackedHeader
            }
            
            if !condense {
                Text(game.description)
                    .font(.dmSans(size: 13, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var inlineHeader: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            
            ZStack {
                Circle()
                    .fill(Color.systemHackersGreen.opacity(0.125))
                    .frame(width: 34, height: 34)
                AwesomeImage(
                    rawIcon: game.icon.unicode,
                    style: .light,
                    size: 17,
                    color: .systemHackersGreen
                )
            }
            
            Text(game.name)
                .font(.fugazOne(size: 24))
                .foregroundColor(Color.systemHackersGreen)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
        }
    }
    
    private var stackedHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.systemHackersGreen.opacity(0.125))
                    .frame(width: 56, height: 56)
                AwesomeImage(
                    rawIcon: game.icon.unicode,
                    style: .light,
                    size: 28,
                    color: .systemHackersGreen
                )
            }
            
            Text(game.name)
                .font(.fugazOne(size: 28))
                .foregroundColor(Color.systemHackersGreen)
                .alignCenter()
        }
    }
}

struct GameCardHeader_Previews: PreviewProvider {
    static var previews: some View {
        GameCardHeader(game: .chaos)
    }
}
