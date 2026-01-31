//
//  PotatoView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/6/24.
//

import SwiftUI

enum PotatoMultipler: Int, CaseIterable {
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    
    var label: String {
        return "\(self.rawValue)x"
    }
    
    var labelLong: String {
        switch self {
        case .one:
            return "🔥"
        case .two:
            return "🔥🔥"
        case .three:
            return "🔥🔥🔥"
        case .four:
            return "🔥🔥🔥🔥"
        case .five:
            return "🔥🔥🔥🔥🔥"
        }
    }
    
    var adjective: String {
        switch self {
        case .one:
            return "room temperature"
        case .two:
            return "pretty warm"
        case .three:
            return "steaming hot"
        case .four:
            return "blazing hot"
        case .five:
            return "actually on fire"
        }
    }
}

enum ActivePotato: Equatable {
    case who
    case player(Player)
    case team(String)
    case nobody
    
    var identifier: String {
        switch self {
        case .who:                  return ""
        case .nobody:               return "nobody"
        case .player(let player):   return player.id
        case .team(let team):       return team
            
        }
    }
    
    var label: String {
        switch self {
        case .who:                      return "Who"
        case .nobody:                   return "Nobody"
        case .player(let player):       return player.name
        case .team(let team):           return team
        }
    }
    
    func subtitle(carryover: Bool = false) -> String {
        switch self {
        case .who:  return "ended with the spud?"
        default:    return carryover ? "starts with the spud." : "ended with the spud."
        }
    }
    
    static func == (lhs: ActivePotato, rhs: ActivePotato) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

struct PotatoView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSessionV2
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    @Binding var hole: Int
    
    @State private var potato: ActivePotato = .who
    @State private var carryover: Bool = false
    @State private var multiplier: PotatoMultipler = .two
    
    @State private var holeScores: [GameScoreData] = []
    @State private var totalScores: [GameScoreData] = []
    @State private var bannerText: String = ""
    
    private var hideOutcomeBanner: Bool {
        bannerText.isEmpty || potato == .who
    }
    
    var body: some View {
        VStack(spacing: 10) {
            if !hideOutcomeBanner {
                InfoBanner(
                    icon: viewModel.sideGame.icon,
                    text: bannerText,
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
            
            HStack(spacing: 10) {
                if totalScores.isEmpty {
                    ForEach(roundSession.players) { player in
                        PlayerScoreTile(
                            player: player,
                            score: "0",
                            placeholder: true
                        )
                    }
                } else {
                    ForEach(totalScores, id: \.self) { total in
                        if let player = roundSession.players.first(where: { $0.id == total.key }) {
                            if let holeScore = holeScores.first(where: { $0.key == player.id }) {
                                PlayerScoreTile(
                                    player: player,
                                    score: "\(total.value.toGolfScore)",
                                    subtitle: "\(holeScore.value.toGolfScore) this hole"
                                )
                            } else {
                                PlayerScoreTile(
                                    player: player,
                                    score: "\(total.value.toGolfScore)",
                                    placeholder: true
                                )
                            }
                        }
                    }
                }
            }
            multiplierMenu
            
            if hideOutcomeBanner {
                InfoBanner(
                    text: "The potato is held by the last player to miss a fairway, lose a ball, hit a bunker, or three putt.",
                    foregroundColor: Color.systemGray
                )
            }
            
            
            potatoMenu
        }
        .onAppear() {
            load(viewModel.sideGameSession.hotPotato)
        }
        .onChange(of: hole) { old, new in
            withAnimation(.linear(duration: 0.2)) {
                load(viewModel.sideGameSession.hotPotato)
            }
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            /// Use nil-coalesce to set initial value here, otherwise `RoundSession` and `ViewModel` side game sessions
            /// will loop back and forth onReceive due to toggling between initial value and nil.
            let p = sideGameSession.hotPotato?.play[hole] ?? ActivePotato.who.identifier
            let m = sideGameSession.hotPotato?.multiplier[hole] ?? PotatoMultipler.two.rawValue
            
            if p == potato.identifier && m == multiplier.rawValue { return }
            
            withAnimation(.easeOut(duration: 0.2)) {
                load(sideGameSession.hotPotato)
            }
        })
        /// Capture scoring changes to re-compute results
        .onReceive(roundSession.$players, perform: { _ in
            withAnimation(.linear(duration: 0.2)) {
                computeTotalScoring()
            }
        })
        /// Publish local changes back to current hole view model
        .onChange(of: potato) { old, new in
//            if old != new && carryover && old == .who {
//                carryover = false
//            }
            
            let value = new.identifier
            if viewModel.sideGameSession.hotPotato?.play[hole] != value {
                print("update potato from local change")
                viewModel.sideGameSession.hotPotato?.play.updateValue(value, forKey: hole)
                computeTotalScoring()
            }
        }
        .onChange(of: multiplier) { old, new in
            let value = new.rawValue
            if viewModel.sideGameSession.hotPotato?.multiplier[hole] != value {
                print("update multiplier from local change")
                viewModel.sideGameSession.hotPotato?.multiplier.updateValue(value, forKey: hole)
                computeTotalScoring()
            }
        }
    }
    
    // MARK: - Functions
    
    private func load(_ session: HotPotatoSession?) {
        guard let s = session else { return }

        let p = convertToPotato(s.play[hole])
        let m = PotatoMultipler(rawValue: s.multiplier[hole] ?? 2) ?? .two
        
        self.potato = p
        self.multiplier = m
        
//        if let previousPotato = viewModel.sideGameSession.hotPotato?.play[hole - 1], potato == .who {
//            carryover = true
//            potato = convertToPotato(previousPotato)
//        }
        
        withAnimation(.linear(duration: 0.2)) {
            computeTotalScoring()
        }
    }
    
    private func convertToPotato(_ value: String?) -> ActivePotato {
        guard let value else { return .who }
        
        if let p = roundSession.players.first(where: { $0.id == value }) {
            return .player(p)
        } else if value == ActivePotato.nobody.identifier {
            return .nobody
        } else if !value.isEmpty {
            return .team(value)
        } else {
            return .who
        }
    }
    
    // MARK: - Components
    
    private var potatoMenu: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Menu {
                    Button {
                        Haptics.fire(.light)
                        potato = .who
                    } label: {
                        Text(ActivePotato.who.label)
                    }
                    
                    Divider()
                    
                    if roundSession.teams.isEmpty {
                        ForEach(roundSession.players, id: \.self) { p in
                            Button {
                                Haptics.fire(.light)
                                potato = ActivePotato.player(p)
                            } label: {
                                Text(p.name)
                            }
                        }
                    } else {
                        ForEach(roundSession.teams, id: \.self) { t in
                            Button {
                                Haptics.fire(.light)
                                potato = ActivePotato.team(t)
                            } label: {
                                Text(t)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        Haptics.fire(.light)
                        potato = .nobody
                    } label: {
                        Text(ActivePotato.nobody.label)
                    }
                } label: {
                    if let p = roundSession.players.first(where: { $0.id == potato.identifier }) {
                        ChipButton(
                            text: potato.label,
                            foregroundColor: p.color.value,
                            backgroundColor: p.color.value.opacity(colorScheme.translucent)
                        ).bold()
                    } else {
                        ChipButton(text: potato.label).bold()
                    }
                }
                .onTapGesture {
                    Haptics.fire(.light)
                }
                
                Text(potato.subtitle(carryover: carryover))
                    .font(.dmSans, size: 17, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
            }
            
            if carryover {
                Text("They'll continue to hold the spud until another player has misfortune.")
                    .font(.dmSans, size: 13, weight: .medium)
                    .foregroundColor(Color.systemGray)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private var multiplierMenu: some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("The spud factor is")
                    .font(.dmSans, size: 17, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                
                Text("Whoever holds the spud has their score multipled by this value on this hole.")
                    .font(.dmSans, size: 13, weight: .medium)
                    .foregroundColor(Color.systemGray)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                    .multilineTextAlignment(.leading)
            }
            
            Spacer(minLength: 0)
            
            Menu {
                ForEach(PotatoMultipler.allCases, id: \.self) { m in
                    Button {
                        Haptics.fire(.light)
                        multiplier = m
                    } label: {
                        Text(m.label)
                    }
                }
            } label: {
                ChipButton(size: .extraLarge, text: multiplier.label).bold()
            }
            .onTapGesture {
                Haptics.fire(.light)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Computation
    
    private func computeHoleScoring() {
        var data: [GameScoreData] = []
        for player in roundSession.players {
            if let score = ScoreUtil.HotPotato.computeScore(
                for: player,
                on: hole,
                with: viewModel.sideGameSession.hotPotato,
                handicaps: roundSession.usingHandicaps
            ) {
                data.append(GameScoreData(key: player.id, value: score))
            }
        }
        self.holeScores = data
    }
    
    private func computeTotalScoring() {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        computeHoleScoring()
        
        var data: [GameScoreData] = []
        for player in roundSession.players {
            let score = ScoreUtil.HotPotato.computeTotal(
                for: player,
                over: Array(range),
                with: viewModel.sideGameSession.hotPotato,
                handicaps: roundSession.usingHandicaps
            )
            data.append(GameScoreData(key: player.id, value: score))
        }
        
        self.totalScores = data.sorted(by: {
            if $0.value == $1.value {
                return index(of: $1.key) > index(of: $0.key)
            } else {
                return $0.value < $1.value
            }
        })
        
        func index(of id: String) -> Int {
            roundSession.players.firstIndex(where: { $0.id == id }) ?? 0
        }
        
        self.bannerText = ScoreUtil.HotPotato.banner(
            for: roundSession.players,
            over: viewModel.sideGameSession.holes,
            for: hole,
            with: viewModel.sideGameSession.hotPotato,
            handicaps: roundSession.usingHandicaps
        )
    }
}

struct PotatoView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.team = [:]
        s.team = [:]
        m.team = [:]
        p.team = [:]
        
        k.score = [1: "birdie", 2: "par"]
        s.score = [1: "par", 2: "bogey"]
        m.score = [1: "eagle", 2: "double"]
        p.score = [1: "bogey", 2: "par"]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        PotatoView(viewModel: viewModel, hole: .constant(3))
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGame = .hotPotato
                viewModel.sideGameSession.holes = Array(1...9)
                roundSession.players = previewPlayers
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
