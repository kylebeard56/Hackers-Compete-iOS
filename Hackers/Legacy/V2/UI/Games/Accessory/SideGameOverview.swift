//
//  SideGameOverview.swift
//  Hackers
//
//  Created by Kyle Beard on 7/16/23.
//

import SwiftUI

struct SideGameOverview: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    private var isLastHole: Bool {
        (roundSession.holeRange.last ?? 0) == roundSession.currentHole
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                
                // TODO: When planning a future game, you need to pick a hole beyond your current hole.
//                VStack(spacing: 20) {
//                    Divider()
//
//                    BigButton(
//                        title: "Plan future side game",
//                        labelColor: .systemWhite,
//                        buttonColor: .systemHackersPurple,
//                        isDisabled: .constant(isLastHole),
//                        isLoading: .false
//                    )
//                    .onTap {
//                        print("todo: show side game selector and then have user pick future hole to start on")
//                    }
//                    .padding(.horizontal, 20)
//                }
            }
            .padding(.vertical, 10)
            .navigationTitle("Overview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
        }
        .environmentObject(roundSession)
        .background(Color.systemViewBackground)
        .padding(.top, 10)
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Group {
                Text("View and manage ")
                    .foregroundColor(Color.systemBlack)
                   // .font(.dmSans, size: 17, weight: .regular)
                + Text("**past, present, and future side games**")
                    .foregroundColor(Color.systemHackersPurple)
                    //.font(.dmSans, size: 17, weight: .bold)
                + Text(" for your round.")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
            }
            .font(.dmSans, size: 17)
            .multilineTextAlignment(.leading)
            .alignLeading()
            
            if roundSession.sideGameSessions.isEmpty {
                Text("No current side games")
                    .foregroundColor(Color.systemGray)
                    .font(.dmSans, size: 17, weight: .regular)
                    .alignCenter()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        ForEach(roundSession.sideGameSessions, id: \.self) { session in
                            tile(for: session)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder private func tile(for session: SideGameSession) -> some View {
        let isCurrent = session.holes.contains(roundSession.currentHole)
        let start = session.holes.first ?? 0
        let finish = session.holes.last ?? 0
        let game = SideGame(rawValue: session.game) ?? .none
        
        let startIndex = roundSession.holeRange.firstIndex(of: start) ?? 0
        let currentIndex = roundSession.holeRange.firstIndex(of: roundSession.currentHole) ?? 0
        let isUpcoming = startIndex > currentIndex
        
        Button(action: {
            print("todo: future action")
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            isCurrent ? Color.systemHackersPurple.opacity(colorScheme.translucent) : Color.systemGray6
                        )
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: game.icon.unicode,
                        style: .regular,
                        size: 24,
                        color: isCurrent ? Color.systemHackersPurple : Color.systemBlack
                    )
                }
                
                VStack(spacing: 4) {
                    HStack {
                        Text(game.name)
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans, size: 20, weight: .bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .alignLeading()
                        
                        Spacer(minLength: 10)
                        
                        if isCurrent {
                            Text("Current")
                                .foregroundColor(Color.systemHackersPurple)
                                .font(.dmSans, size: 13, weight: .bold)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 10) {
                        Text("Holes \(start) - \(finish)")
                            .foregroundColor(Color.systemGray)
                            .font(.dmSans, size: 13, weight: .medium)
                        
                        if isUpcoming {
                            Circle()
                                .fill(Color.systemGray3)
                                .frame(width: 4, height: 4)

                            Text("Upcoming")
                                .foregroundColor(Color.systemGray)
                                .font(.dmSans, size: 13, weight: .medium)
                        }
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                colorScheme.lightGray,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder private func grid(for session: SideGameSession) -> some View {
        let isCurrent = session.holes.contains(roundSession.currentHole)
        let start = session.holes.first ?? 0
        let end = session.holes.last ?? 0
        let game = SideGame(rawValue: session.game) ?? .none
                    
        VStack(spacing: 6) {
            Text("Holes \(start) - \(end)")
                .font(.dmSans, size: 15, weight: .bold)
                .foregroundColor(Color.systemGray)
                .alignLeading()
            
            HStack(spacing: 10) {
                AwesomeImage(
                    rawIcon: game.icon.unicode,
                    style: .regular,
                    size: 17,
                    color: Color.systemBlack
                )
                Text(game.name)
                    .font(.dmSans, size: 17, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                if isCurrent {
                    Text("Active")
                        .font(.dmSans, size: 17, weight: .bold)
                        .foregroundColor(Color.systemHackersPurple)
                }
            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
            .padding(20)
            .background(Color.systemCard)
            .border(
                colorScheme.lightGray,
                width: 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
}

struct SideGameOverview_Previews: PreviewProvider {
    static var previews: some View {
        SideGameOverview()
    }
}
