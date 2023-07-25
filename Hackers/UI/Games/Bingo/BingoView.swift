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
            .debounce(for: .milliseconds(375), scheduler: DispatchQueue.main)
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
    
    func value(for data: BingoData) -> String {
        switch self {
        case .bingo: return data.bingo
        case .bango: return data.bango
        case .bongo: return data.bongo
        }
    }
}

struct BingoView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var data: Debounced<BingoData> = Debounced(value: BingoData())
    @State private var totalScores: [String: Int] = [:]
    @State private var didJustAppearLock: Bool = true
    
    @State private var bingo: Player?
    @State private var bango: Player?
    @State private var bongo: Player?
    
    var body: some View {
        VStack(spacing: 10) {
            scoreboardTile
            pointsTile
        }
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: { self.didJustAppearLock = false })
            if let d = viewModel.sideGameSession.bingo?.play[hole] {
                data = Debounced(value: d)
            }
            refresh()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            if let d = sideGameSession.bingo?.play[hole], d != data.value {
                data = Debounced(value: d)
            }
            refresh()
        })
        /// Publish local changes back to current hole view model
        .onReceive(data.$debouncedValue, perform: { value in
            if value.isEmpty && didJustAppearLock { return }
            
            var map: [Int: BingoData] = viewModel.sideGameSession.bingo?.play ?? [:]
            map.updateValue(value, forKey: hole)
            viewModel.sideGameSession.bingo = BingoSession(play: map)
            refresh()
        })
        /// Display local view changes
        .onReceive(data.$value, perform: { value in
            bingo = roundSession.players.first(where: { $0.id == value.bingo })
            bango = roundSession.players.first(where: { $0.id == value.bango })
            bongo = roundSession.players.first(where: { $0.id == value.bongo })
        })
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
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private func scoreRow(for type: ScoreType) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(type.rawValue)
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                
                Text(type.subtitle)
                    .font(.dmSans(size: 12, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
            }
            
            Spacer(minLength: 0)
            
            Button(action: {
                rotate(for: type)
                Haptics.fire(.light)
            }) {
                if type == .bingo { chip(for: bingo) }
                if type == .bango { chip(for: bango) }
                if type == .bongo { chip(for: bongo) }
            }
        }
    }

    private func chip(for player: Player?) -> some View {
        VStack {
            if let player {
                ChipButton(
                    text: player.name,
                    foregroundColor: player.color.value,
                    backgroundColor: player.color.value.opacity(colorScheme.translucent)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            } else {
                ChipButton(text: "Select")
            }
        }
    }
    
    private func rotate(for type: ScoreType) {
        var value = ""
        if type == .bingo { value = data.value.bingo }
        if type == .bango { value = data.value.bango }
        if type == .bongo { value = data.value.bongo }
        
        if value.isEmpty {
            // None -> Player 1
            // Player n -> Player n + 1
            if type == .bingo { data.value.bingo = roundSession.players[0].id }
            if type == .bango { data.value.bango = roundSession.players[0].id }
            if type == .bongo { data.value.bongo = roundSession.players[0].id }
        } else if let i = roundSession.players.firstIndex(where: { $0.id == value }) {
            if (roundSession.players.last?.id ?? "") == roundSession.players[i].id {
                // Player ...n -> None
                if type == .bingo { data.value.bingo = "" }
                if type == .bango { data.value.bango = "" }
                if type == .bongo { data.value.bongo = "" }
            } else {
                // Player n -> Player n + 1
                if type == .bingo { data.value.bingo = roundSession.players[i+1].id }
                if type == .bango { data.value.bango = roundSession.players[i+1].id }
                if type == .bongo { data.value.bongo = roundSession.players[i+1].id }
            }
        }
    }
    
    // MARK: - Points
    
    @ViewBuilder private var pointsTile: some View {
        VStack(spacing: 8) {
            Text("Points")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            ForEach(roundSession.players, id: \.self) { player in
                HStack {
                    Text(player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    Text("\(totalScores[player.id] ?? 0)")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private func refresh() {
        self.totalScores = ScoreUtil.Bingo.computeTotal(
            for: roundSession.players,
            playing: viewModel.sideGameSession.bingo,
            over: viewModel.sideGameSession.holes,
            upTo: hole
        )
    }
}

struct BingoView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var viewModel = HoleViewModel()
    static var previews: some View {
        BingoView(viewModel: viewModel, hole: 5)
            .environmentObject(roundSession)
            .onAppear() {
                viewModel.sideGameSession.holes = [1, 2, 3, 4]
                viewModel.sideGameSession.bingo = BingoSession(play: [
                    1: BingoData(bingo: "kyle", bango: "murphy", bongo: "sarah"),
                    2: BingoData(bingo: "sarah", bango: "kyle", bongo: "pablo"),
                    3: BingoData(bingo: "sarah", bango: "murphy", bongo: "pablo"),
                    4: BingoData(bingo: "kyle", bango: "murphy", bongo: "kyle"),
                    5: BingoData(bingo: "", bango: "murphy", bongo: "")
                ])
                roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
            }
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
