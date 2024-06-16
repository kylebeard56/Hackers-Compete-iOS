//
//  LeaderboardView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/11/24.
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    
    @StateObject var viewModel: HoleViewModel
    var hole: Int
    
    @State private var showLeaderboardMenu: Bool = false
    @State private var showScorecard: Bool = false
    @State private var showPlayerScorecard: Bool = false
    @State private var scorecardIndex: Int = 0
    
    var body: some View {
        content
            .onReceive(HackersNotification.displayPlayerScorecard.publisher(), perform: { data in
                showPlayerScorecard = false
                if let index = data.object as? Int {
                    scorecardIndex = index
                    showPlayerScorecard = true
                }
            })
            .sheet(isPresented: $showScorecard) {
                ScorecardView()
                    .presentationDetents([.height(roundSession.scorecardHeight)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showLeaderboardMenu) {
                LeaderboardMenuView()
                    .presentationDetents([.height(420)])
                    .presentationDragIndicator(.visible)
            }
    }
    
    private var content: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Leaderboard")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                HStack(spacing: 32) {
                    Button(action: {
                        self.showScorecard = true
                        Haptics.fire(.light)
                    }) {
                        AwesomeImage(rawIcon: "f00a".unicode, style: .regular, size: 20, color: .systemBlack)
                    }
                    
                    Button(action: {
                        self.showLeaderboardMenu = true
                        Haptics.fire(.light)
                    }) {
                        // f044 is pencil square, f142 is ellipsis
                        AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 20, color: .systemBlack)
                    }
                }
            }
            
            if viewModel.teams.isEmpty || !roundSession.teamRowDisplay {
                VStack(spacing: 10) {
                    ForEach($roundSession.players, id: \.self) { player in
                        LeaderboardPlayerRow(player: player, hole: hole)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.teams, id: \.self) { team in
                        LeaderboardTeamRow(team: team, hole: hole)
                    }
                }
            }
            
            if !viewModel.teams.isEmpty {
                HStack(spacing: 4) {
                    Text("Display rows as")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemGray)
                    
                    Button(action: {
                        Haptics.fire(.light)
                        withAnimation(.easeOut(duration: 0.2)) {
                            roundSession.teamRowDisplay.toggle()
                        }
                    }) {
                        ChipButton(
                            text: roundSession.teamRowDisplay ? "teams" : "players",
                            backgroundColor: colorScheme.superlightGray
                        )
                    }
                    
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var app = AppSession()
    static var purchase = PurchaseStore()
    static var round = RoundSession()
    static var viewModel = HoleViewModel()
    
    static var previews: some View {
        LeaderboardView(viewModel: viewModel, hole: 1)
            .environmentObject(app)
            .environmentObject(purchase)
            .environmentObject(round)
            .holisticPreview()
            .onAppear() {
                round.currentHole = 1
                round.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                round.teams = ["Team one", "Team two"]
            }
    }
}
