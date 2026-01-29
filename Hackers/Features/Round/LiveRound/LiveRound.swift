//
//  LiveRound.swift
//  Hackers
//
//  Created by Kyle Beard on 1/21/26.
//


import SwiftUI

private enum Tab: String {
    case scoring, games, map, chat
}

struct LiveRound: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    var snapshot: RoundSnapshot { roundSession.snapshot }
    
    @State private var selectedTab: Tab = .scoring
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    var body: some View {
        VStack {
            HStack {
                NavButton() { dismiss() }
                Spacer(minLength: 0)
                
                // [ASAP] TODO: Course name and high-level round detail
                // The Preserve at Verdae
                // Week 11
                // -or-
                // The Cliffs at Mountain Park
                // Single round / Scramble / Stroke play / Match play
                
                Spacer(minLength: 0)
                NavButton(icon: "gear") { print("todo: round configuration") }
            }
            
            // [FUTURE] TODO: Make custom tab bar like Instagram
            TabView(selection: $selectedTab) {
                scoringContent
                    .tabItem {
                        Image(systemName: "menucard")
                    }
                    .tag(Tab.scoring)

                gameContent
                    .tabItem {
                        Image(systemName: "figure.golf")
                    }
                    .tag(Tab.games)

                mapContent
                    .tabItem {
                        Image(systemName: "map")
                    }
                    .tag(Tab.map)

                chatContent
                    .tabItem {
                        Image(systemName: "bubble")
                    }
                    .tag(Tab.chat)
            }
            .tint(palette.foregroundColor)
            .toolbarBackground(palette.backgroundColor, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .scaleEffect(tabBarScale, anchor: .bottom)
        }
        .padding(.horizontal, 16)
        .navigationBarBackButtonHidden(true)
        .task {
            print("LIVE ROUND:")
            printPretty(roundSession.snapshot)
        }
    }
    
    // MARK: - Scoring
    
    @State private var tabBarScale: CGFloat = 1.0
    @State private var offset: CGFloat = 0.0
    @State private var previousOffset: CGFloat = 0
    
    private var scoringContent: some View {
        ObservableScrollView(offset: $offset) {
            VStack(spacing: 16) {
                ForEach(0...100, id: \.self) { i in
                    Text("Row \(i)")
                        .alignLeading()
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color.neutral6)
        .onChange(of: offset) {
            updateTabBarScale()
        }
    }
    
    func updateTabBarScale(
        shrinkSpeed: CGFloat = 0.015,
        expandSpeed: CGFloat = 0.02,
        minScale: CGFloat = 0.7,
        maxScale: CGFloat = 1.0
    ) {
        let delta = offset - previousOffset
        previousOffset = offset
        
        // Scrolling down → content moves up → shrink
        if delta < 0 {
            tabBarScale = max(minScale, tabBarScale + delta * shrinkSpeed)
        }
        
        // Scrolling up → expand
        else if delta > 0 {
            tabBarScale = min(maxScale, tabBarScale + delta * expandSpeed)
        }
    }

    // MARK: - Game Content
    
    private var gameContent: some View {
        // Alternative side games, or bets.
        VStack {
            Text("Side game content coming soon")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
    
    // MARK: - Map Content
    
    private var mapContent: some View {
        // Ideas: Have users enter their stock yardage per club. Then you have Bushnell-like map where you can tap
        // and drag waypoints and along the straight line, you can see distance, suggested club with power so you
        // can decide whether you're driver-wedge, 5i-8i, 6i-6i etc to balance what's best and strategize the hole.
        // The user has to be the one to know where the are on the map.
        VStack {
            Text("Map content coming soon")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
    
    // MARK: - Chat Content
    
    private var chatContent: some View {
        // Place for players to chat, share pics, post announcements.
        VStack {
            Text("In-round chat coming soon")
                .fontStyle(.poppins, size: 20, weight: .medium)
                .alignCenter()
                .alignMiddle()
        }
        .padding(16)
    }
}

@MainActor
private enum Mock {
    static var appSesssion: AppSession {
        return .init()
    }
    
    static var roundSesssion: RoundSession {
        return .init()
    }
}

#Preview {
    LiveRound()
        .environmentObject(Mock.appSesssion)
        .environmentObject(Mock.roundSesssion)
}
