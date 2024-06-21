//
//  BingoView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/24/23.
//

import SwiftUI

import Combine
class Debounced<T>: Hackable {
    @Published var value: T
    @Published var debouncedValue: T
    
    private var subscription = Set<AnyCancellable>()
    
    init(value: T) {
        self.value = value
        self.debouncedValue = value
        
        $value
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink(receiveValue: { [weak self] value in self?.debouncedValue = value })
            .store(in: &subscription)
    }
}

private enum ScoreType: String, CaseIterable {
    case bingo = "Bingo"
    case bango = "Bango"
    case bongo = "Bongo"
    
    var subtitle: String {
        switch self {
        case .bingo:    return "First to reach the green"
        case .bango:    return "Closest to the pin when all on green"
        case .bongo:    return "Longest putt made"
        }
    }
    
    func value(for BingoData: BingoData) -> String {
        switch self {
        case .bingo: return BingoData.bingo
        case .bango: return BingoData.bango
        case .bongo: return BingoData.bongo
        }
    }
}

struct BingoView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var bingoData: Debounced<BingoData> = Debounced(value: BingoData())
    @State private var totalScores: [String: Int] = [:]
    @State private var didJustAppearLock: Bool = true
    
    @State private var data: [GameScoreData] = []
    
    @State private var bingo: Player?
    @State private var bango: Player?
    @State private var bongo: Player?
    
    var body: some View {
        VStack(spacing: 10) {
            if viewModel.teams.isEmpty {
                playerTiles
            } else {                
                teamTiles
            }
            
            scoreboardTile
        }
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: { self.didJustAppearLock = false })
            if let d = viewModel.sideGameSession.bingo?.play[hole] {
                bingoData = Debounced(value: d)
            }
            compute()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            if roundSession.isInSync { return }
            if let d = sideGameSession.bingo?.play[hole], d != bingoData.value { bingoData = Debounced(value: d) }
            compute()
        })
        /// Publish local changes back to current hole view model
        .onReceive(bingoData.$debouncedValue, perform: { value in
            /// If the BingoData is empty and just appeared, it could accidently overwrite hole with blank BingoData.
            if value.isEmpty && didJustAppearLock { return }
            
            var map: [Int: BingoData] = viewModel.sideGameSession.bingo?.play ?? [:]
            map.updateValue(value, forKey: hole)
            viewModel.sideGameSession.bingo = BingoSession(play: map)
            compute()
        })
        /// Display local view changes
        .onReceive(bingoData.$value, perform: { value in
            bingo = roundSession.players.first(where: { $0.id == value.bingo })
            bango = roundSession.players.first(where: { $0.id == value.bango })
            bongo = roundSession.players.first(where: { $0.id == value.bongo })
        })
    }
    
    // MARK: - Tiles
    
    @ViewBuilder private var playerTiles: some View {
        HStack(spacing: 10) {
            ForEach(data, id: \.self) { d in
                if let p = roundSession.players.first(where: { $0.id == d.key }) {
                    PlayerScoreTile(player: p, score: "\(d.value)")
                }
            }
        }
    }
    
    @ViewBuilder private var teamTiles: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.teams, id: \.self) { team in
                let players = roundSession.players.filter({ $0.team[hole] == team })
                let ids = players.compactMap({ $0.id })
                let score = totalScores.filter({ ids.contains($0.key) }).values.reduce(0, +)
                
                TeamScoreTile(team: team, score: "\(score)", hole: hole, scale: 2)
            }
        }
    }
    
    // MARK: - Scoreboard
    
    @ViewBuilder private var scoreboardTile: some View {
        VStack(spacing: 16) {
            ForEach(ScoreType.allCases, id: \.rawValue) { type in
                scoreRow(for: type)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private func scoreRow(for type: ScoreType) -> some View {
        Menu {
            Button {
                Haptics.fire(.light)
                setScore(to: "", for: type)
            } label: {
                Text("Select")
            }
            Divider()
            ForEach(roundSession.players, id: \.self) { p in
                Button {
                    Haptics.fire(.light)
                    setScore(to: p.id, for: type)
                } label: {
                    Text(p.name)
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text(type.rawValue)
                        .font(.dmSans, size: 20, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .alignLeading()
                    
                    Text(type.subtitle)
                        .font(.dmSans, size: 12, weight: .regular)
                        .foregroundColor(Color.systemGray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .alignLeading()
                }
                
                Spacer(minLength: 0)
                
                if type == .bingo { chip(for: bingo) }
                if type == .bango { chip(for: bango) }
                if type == .bongo { chip(for: bongo) }
            }
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    private func setScore(to value: String, for type: ScoreType) {
        if type == .bingo { bingoData.value.bingo = value }
        if type == .bango { bingoData.value.bango = value }
        if type == .bongo { bingoData.value.bongo = value }
    }

    private func chip(for player: Player?) -> some View {
        VStack {
            if let player {
                ChipButton(
                    text: player.name,
                    foregroundColor: player.color.value,
                    backgroundColor: player.color.value.opacity(colorScheme.translucent)
                )
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            } else {
                ChipButton(text: "Select").bold()
            }
        }
    }
    
    // MARK: - Computation
    
    private func compute() {
        totalScores = ScoreUtil.Bingo.computeTotal(
            for: roundSession.players,
            playing: viewModel.sideGameSession.bingo,
            over: viewModel.sideGameSession.holes,
            upTo: hole
        )
        
        data = totalScores
            .compactMap({ GameScoreData(key: $0.key, value: $0.value) })
            .sorted(by: {
                if $0.value == $1.value {
                    return index(of: $1.key) > index(of: $0.key)
                } else {
                    return $0.value > $1.value
                }
            })
        
        func index(of id: String) -> Int {
            roundSession.players.firstIndex(where: { $0.id == id }) ?? 0
        }
    }
}

struct BingoView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    static var previews: some View {
        BingoView(viewModel: viewModel, hole: 1)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.teams = ["Team one", "Team two"]
                viewModel.sideGameSession.holes = [1, 2, 3, 4]
                viewModel.sideGameSession.bingo = BingoSession(play: [
                    1: BingoData(bingo: "kyle", bango: "murphy", bongo: "sarah"),
                    2: BingoData(bingo: "sarah", bango: "kyle", bongo: "pablo"),
                    3: BingoData(bingo: "sarah", bango: "murphy", bongo: "pablo"),
                    4: BingoData(bingo: "kyle", bango: "murphy", bongo: "kyle"),
                    5: BingoData(bingo: "", bango: "murphy", bongo: "")
                ])
                
                roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                roundSession.teams = ["Team one", "Team two"]
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
