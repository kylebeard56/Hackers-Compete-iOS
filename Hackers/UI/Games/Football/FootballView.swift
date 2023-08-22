//
//  FootballView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

/// Requires teams of 4 set 2v2
/// On first tee, we say possession is furthest off tee, then for future holes it's whoever had possession unless scoring.
///
/// While playing,
///     Lost ball or bunker hit is a change of possession (sequentially).
///     Once everyone finishes hole, scoring is based based on final possession.
///
/// When done,
///    if offensive team has best ball, they have option to take FG or go for TD (win hole again).
///    if defense has best ball (or tie), they get turnover on downs and possession next hole.
///    if both defensive players beat offense, they get safety and possession next hole.

struct FootballView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var data: [GameScoreData] = []
    @State private var showTeamStructure: Bool = false
    
    /// Current hole data
    @State private var possession: String = ""
    @State private var onsideKickAttempt: Bool = false
    @State private var onsideKickSuccess: Bool?
    
    /// Previous hole data
    @State private var previousPlayers: String = ""
    @State private var verb: String = ""
    @State private var previousOffense: String = ""
    @State private var previousDefense: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            if viewModel.teams.isEmpty {
                BigButton(
                    title: "Set teams to play",
                    appleIcon: "plus.circle",
                    buttonColor: Color.systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    showTeamStructure = true
                }
                .padding(.top, 10)
            } else {
                content
            }
        }
        .onAppear() {
            load(viewModel.sideGameSession.football)
            compute()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            withAnimation(.easeOut(duration: 0.2)) {
                load(viewModel.sideGameSession.football)
                compute()
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            compute()
        })
        /// Publish local changes back to current hole view model
        .onChange(of: possession, perform: { value in
            if viewModel.sideGameSession.football?.possession[hole] != value {
                print("update possession from local change \(value)")
                viewModel.sideGameSession.football?.possession.updateValue(value, forKey: hole)
                compute()
            }
        })
        .onChange(of: onsideKickAttempt, perform: { value in
            if viewModel.sideGameSession.football?.onsideKick[hole]?.attempted != value {
                print("update onside attempt from local change \(value)")
                let onside = OnsideKick(attempted: value, successful: onsideKickSuccess)
                viewModel.sideGameSession.football?.onsideKick.updateValue(onside, forKey: hole)
                compute()
            }
        })
        .onChange(of: onsideKickSuccess, perform: { value in
            if viewModel.sideGameSession.football?.onsideKick[hole]?.successful != value {
                print("update onside success from local change \(value)")
                let onside = OnsideKick(attempted: onsideKickAttempt, successful: value)
                viewModel.sideGameSession.football?.onsideKick.updateValue(onside, forKey: hole)
                compute()
            }
        })
        .fullScreenCover(isPresented: $showTeamStructure) {
            TeamStructureView()
        }
    }
    
    // MARK: - Load
    
    private func load(_ s: FootballSession?) {
        possession = s?.possession[hole] ?? ""
        
        previousOffense = s?.possession[hole - 1] ?? ""
        let players = roundSession.players.filter({ $0.team[hole - 1] == previousOffense }).uniques
        previousPlayers = playerNames(for: players)
        switch players.count {
        case 1: verb = "hit"
        case 2:  verb = "both hit"
        default: verb = "all hit"
        }
        
        previousDefense = roundSession.players
            .compactMap({ $0.team[hole - 1] })
            .first(where: { $0 != previousOffense }) ?? ""
        
        if let onside = s?.onsideKick[hole] {
            onsideKickAttempt = onside.attempted
            onsideKickSuccess = onside.successful
        }
    }
    
    // MARK: - Content
    
    private var content: some View {
        VStack(spacing: 10) {
            if viewModel.sideGameSession.holes.first == hole {
                InfoBanner(
                    icon: SideGame.football.icon,
                    text: "Let's kickoff! Whoever has the furthest tee shot starts on offense.",
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
            
            if !previousPlayers.isEmpty {
                onsideKickToggle
            }
            
            possessionSelectionRow
            
            HStack(spacing: 10) {
                ForEach(viewModel.teams, id: \.self) { team in
                    teamTile(for: team)
                }
            }
        }
    }
    
    @ViewBuilder private var possessionSelectionRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Who finished on offense?")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                
                Spacer(minLength: 0)
                
                possessionMenu
            }
            
            /// Possession is set -> nudge user to enter scores in leaderboard
            if !possession.isEmpty && !roundSession.scoringExists(for: hole) {
                Text("Leaderboard scores are needed to see points.")
                    .font(.dmSans(size: 13, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    @ViewBuilder private var possessionMenu: some View {
        Menu {
            Button {
                Haptics.fire(.light)
                possession = ""
            } label: {
                Text("Select")
            }
            Divider()
            ForEach(viewModel.teams, id: \.self) { team in
                Button {
                    Haptics.fire(.light)
                    possession = team
                } label: {
                    Text(team)
                }
            }
        } label: {
            ChipButton(
                text: !possession.isEmpty ? possession : "Select",
                foregroundColor: !possession.isEmpty ? Color.systemHackersPurple : Color.systemBlack,
                backgroundColor: Color.systemGray6
            )
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    @ViewBuilder private var onsideKickToggle: some View {
        VStack(spacing: 10) {
            Toggle(isOn: $onsideKickAttempt, label: {
                VStack(spacing: 4) {
                    Text("Onside kick")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    Text("**\(previousOffense)** can try to stay on offense.")
                        .font(.dmSans(size: 13, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                }
            })
            .tint(Color.systemHackersPurple)
            
            if onsideKickAttempt {
                Text("Did \(previousPlayers) \(verb) the fairway/green?")
                    .font(.dmSans(size: 13, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
                    .padding(.top, 10)
                
                let success = onsideKickSuccess == true
                let failure = onsideKickSuccess == false
                
                HStack(spacing: 10) {
                    BigButton(
                        style: success ? .solid : .outline,
                        title: "Yes",
                        labelColor: success ? .white : .systemHackersPurple,
                        buttonColor: success ? .systemHackersPurple : .systemHackersPurple,
                        height: 40,
                        fontSize: 15,
                        radius: 8,
                        isDisabled: .false,
                        isLoading: .false
                    )
                    .onTap {
                        onsideKickSuccess = success ? nil : true
                    }
                    
                    BigButton(
                        style: failure ? .solid : .outline,
                        title: "No",
                        labelColor: failure ? .white : .systemHackersPurple,
                        buttonColor: failure ? .systemHackersPurple : .systemHackersPurple,
                        height: 40,
                        fontSize: 15,
                        radius: 8,
                        isDisabled: .false,
                        isLoading: .false
                    )
                    .onTap {
                        onsideKickSuccess = failure ? nil : false
                    }
                }
                
                if let o = onsideKickSuccess, onsideKickAttempt {
                    let msg = o
                    ? "Nice work! \(previousOffense) keeps possession."
                    : "Safety! \(previousDefense) scores 2 points!"
                    
                    InfoBanner(
                        icon: SideGame.football.icon,
                        text: msg,
                        foregroundColor: Color.systemHackersPurple,
                        backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    /// This is a dupe of the Session extension helper.
    private func playerNames(for players: [Player]) -> String {
        func name(for i: Int) -> String { return players[safe: i]?.name ?? "" }
        switch players.count {
        case 1:     return "\(name(for: 0))"
        case 2:     return "\(name(for: 0)) and \(name(for: 1))"
        case 3:     return "\(name(for: 0)), \(name(for: 1)), and \(name(for: 2))"
        case 4:     return "\(name(for: 0)), \(name(for: 1)), \(name(for: 2)), and \(name(for: 3))"
        default:    return ""
        }
    }
    
    // MARK: - Team Tiles
    
    @ViewBuilder private func teamTile(for name: String) -> some View {
        VStack(spacing: 8) {
            if let score = data.first(where: { $0.key == name }) {
                TeamScoreRow(name: name, score: "\(score.value)")
            } else {
                TeamScoreRow(name: name, score: "-")
            }
            
            ForEach(Array(roundSession.players.enumerated()), id: \.element) { index, player in
                if player.team[hole] == name {
                    Button {
                        HackersNotification.displayPlayerScorecard.send(with: index)
                        Haptics.fire(.light)
                    } label: {
                        let score = player.score(
                            for: hole,
                            handicaps: roundSession.usingHandicaps
                        ).numericalValue.toGolfScore
                        PlayerScoreRow(player: player, score: score)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Computation
    
    private func compute() {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        self.data = ScoreUtil.Football.computeTotal(
            for: roundSession.players,
            playing: viewModel.sideGameSession.football,
            over: Array(range),
            on: hole,
            handicaps: roundSession.usingHandicaps
        ).sorted(by: { $0.value > $1.value })
    }
}

struct FootballView_Previews: PreviewProvider {
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGameSession.holes = [1, 2, 3, 4]
        vm.teams = ["Team one", "Team two"]
        vm.sideGameSession.football = FootballSession(
            possession: [
                1: "Team one",
                2: "Team two",
                3: "Team one",
                4: "Team two"
            ],
            onsideKick: [
                1: OnsideKick(),
                2: OnsideKick(attempted: true),
                3: OnsideKick(),
                4: OnsideKick(),
            ]
        )
        return vm
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        rs.teams = ["Team one", "Team two"]
        return rs
    }
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        s.team = [1: "Team one", 2: "Team one", 3: "Team one", 4: "Team one"]
        m.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        p.team = [1: "Team two", 2: "Team two", 3: "Team two", 4: "Team two"]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "par", 2: "par", 3: "birdie", 4: "par"]
        m.score = [1: "par", 2: "birdie", 3: "par", 4: "par"]
        p.score = [1: "birdie", 2: "par", 3: "par", 4: "birdie"]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        ScrollView {
            FootballView(viewModel: viewModel, hole: 2)
                .alignTop()
        }
        .environmentObject(roundSession)
        .padding(.horizontal, 20)
        .holisticPreview()
    }
}
