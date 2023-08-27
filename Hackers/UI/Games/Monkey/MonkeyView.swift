//
//  MonkeyView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

/// How to play:
/// Team picks monkey based on middle distance shot or to pin.
/// They then take on the other two 2v1 doubling score for best ball w/ skins?

struct MonkeyView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var scores: [GameScoreData] = []
    @State private var monkey: String = ""
    @State private var skins: Bool = false
    @State private var bannerText: String = ""
    
    var body: some View {
        VStack(spacing: 10) {
            if !bannerText.isEmpty {
                InfoBanner(
                    icon: viewModel.sideGame.icon,
                    text: bannerText,
                    foregroundColor: Color.systemHackersPurple,
                    backgroundColor: Color.systemHackersPurple.opacity(colorScheme.translucent)
                )
            }
            
            content
            
            HStack(spacing: 10) {
                ForEach(scores, id: \.self) { score in
                    if let player = roundSession.players.first(where: { $0.id == score.key }) {
                        if roundSession.everyoneScored(on: hole) {
                            PlayerScoreTile(
                                player: player,
                                score: "\(score.value)",
                                subtitle: "\(player.score(for: hole).shortName)\(player.id == monkey ? " (x2)" : "")",
                                color: player.id == monkey ? player.color.value : nil
                            )
                        } else {
                            PlayerScoreTile(
                                player: player,
                                score: "\(score.value)",
                                color: player.id == monkey ? player.color.value : nil
                            )
                        }

                    }
                }
            }
            
            skinsToggle
        }
        .onAppear() {
            monkey = viewModel.sideGameSession.monkey?.play[hole] ?? ""
            skins = viewModel.sideGameSession.monkey?.skins ?? false
            compute()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            withAnimation(.easeOut(duration: 0.2)) {
                monkey = viewModel.sideGameSession.monkey?.play[hole] ?? ""
                skins = viewModel.sideGameSession.monkey?.skins ?? false
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            compute()
        })
        /// Publish local changes back to current hole view model
        .onChange(of: skins, perform: { value in
            viewModel.sideGameSession.monkey?.skins = value
            compute()
        })
        .onChange(of: monkey, perform: { value in
            viewModel.sideGameSession.monkey?.play.updateValue(value, forKey: hole)
            compute()
        })
    }
    
    // MARK: - Content
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 16) {
            monkeySelectionRow
        }
    }
    
    // MARK: - Monkey row
    
    private var monkeySelectionRow: some View {
        HStack(spacing: 8) {
            scoringMenu
            
            Text("is the monkey\(monkey.isEmpty ? "?" : ".")")
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    private var scoringMenu: some View {
        Menu {
            Button {
                Haptics.fire(.light)
                monkey = ""
            } label: {
                Text("Select")
            }
            Divider()
            ForEach(roundSession.players, id: \.self) { p in
                Button {
                    Haptics.fire(.light)
                    monkey = p.id
                } label: {
                    Text(p.name)
                }
            }
        } label: {
            menuChip
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    private var menuChip: some View {
        VStack {
            if let player = roundSession.players.first(where: { $0.id == monkey }) {
                ChipButton(
                    text: player.name,
                    foregroundColor: player.color.value,
                    backgroundColor: player.color.value.opacity(colorScheme.translucent)
                )
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            } else {
                ChipButton(text: "Which player").bold()
            }
        }
    }
    
    // MARK: - Skins
    
    @ViewBuilder private var skinsToggle: some View {
        Toggle(isOn: $skins, label: {
            VStack(spacing: 4) {
                Text("Skins")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Text("Ties roll points over to the next hole.")
                    .font(.dmSans(size: 13, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .alignLeading()
            }
        })
        .tint(Color.systemHackersPurple)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    // MARK: - Algorithm
    
    private func compute() {
        let left = roundSession.holeRange.firstIndex(of: viewModel.sideGameSession.holes.first ?? 0) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        
        self.scores = ScoreUtil.Monkey.computeTotal(
            for: roundSession.players,
            over: Array(range),
            monkeys: viewModel.sideGameSession.monkey?.play ?? [:],
            skins: skins,
            handicaps: roundSession.usingHandicaps
        )
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
        
        self.bannerText = ScoreUtil.Monkey.banner(
            for: roundSession.players,
            over: viewModel.sideGameSession.holes,
            for: hole,
            monkeys: viewModel.sideGameSession.monkey?.play ?? [:],
            skins: skins,
            handicaps: roundSession.usingHandicaps
        )
    }
}

struct MonkeyView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy

        k.team = [:]
        s.team = [:]
        m.team = [:]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "birdie"]
        s.score = [1: "par", 2: "par", 3: "bogey", 4: "par"]
        m.score = [1: "par", 2: "birdie", 3: "double", 4: "par"]
        
        return [k, s, m]
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        return rs
    }
    
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGame = .monkeyInTheMiddle
        vm.sideGameSession.holes = [1, 2, 3, 4]
        vm.sideGameSession.monkey = MonkeySession(
            play: [1: "kyle", 2: "sarah", 3: "murphy", 4: "murphy"],
            skins: true
        )
        return vm
    }
    
    static var previews: some View {
        MonkeyView(viewModel: viewModel, hole: 3)
            .environmentObject(roundSession)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
