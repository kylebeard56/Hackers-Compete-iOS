//
//  SideGameResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/16/23.
//

import SwiftUI

struct SideGameResultsView<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    var winnerLabel: String = "Winner"
    @ViewBuilder var content: () -> Content
    
    @State private var expand: Bool = false
    
    var body: some View {
        VStack(spacing: 10) {
            header
            if expand {
                content()
            }
        }
        .environmentObject(roundSession)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(
            colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
            width: 3,
            cornerRadius: 12
        )
        .cornerRadius(12)
    }
    
    // MARK: - Content
    
    @ViewBuilder private var header: some View {
        let start = session.holes.first ?? 0
        let finish = session.holes.last ?? 0
        let game = SideGame(rawValue: session.game) ?? .none
        
        Button(action: {
            if !expand {
                HackersNotification.sideGameResultsTapped.send(with: session.id)
            }
            withAnimation(.linear(duration: 0.2)) { expand.toggle() }
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersGold.opacity(colorScheme.translucent))
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: game.icon.unicode,
                        style: .regular,
                        size: 24,
                        color: Color.systemHackersGold
                    )
                }
                
                VStack(spacing: 4) {
                    Text(game.name)
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 20, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignLeading()
                    
                    HStack(spacing: 0) {
                        Text("Holes \(start) - \(finish)")
                            .foregroundColor(Color.systemGray)
                            .font(.dmSans(size: 13, weight: .medium))
                        
                        Spacer(minLength: 10)
                        
                        HStack {
                            Text(winnerLabel)
                            AwesomeImage(
                                rawIcon: "f054".unicode,
                                style: .solid,
                                size: 10,
                                color: Color.systemHackersGold
                            )
                            .rotationEffect(Angle(degrees: expand ? 90 : 0))
                        }
                        .foregroundColor(Color.systemHackersGold)
                        .font(.dmSans(size: 13, weight: .bold))
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(Color.systemHackersGold.opacity(colorScheme.translucent))
                        .cornerRadius(4)
                    }
                }
            }
        }
    }
    
    @ViewBuilder private var results: some View {
        Text("Coming soon")
    }
}

struct SideGameResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SideGameResultsView(session: SideGameSession(), content: {})
    }
}
