//
//  MonkeyPlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

/// How to play:
/// Team picks monkey based on middle distance shot or to pin.
/// They then take on the other two 2v1 doubling score for best ball w/ skins?

struct MonkeyPlayView: View {
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
                HStack(spacing: 10) {
                    AwesomeImage(rawIcon: "f091".unicode, style: .regular, size: 15, color: Color.systemHackersPurple)
                    Text(LocalizedStringKey(bannerText))
                        .foregroundColor(Color.systemHackersPurple)
                        .font(.dmSans(size: 13, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                .cornerRadius(12)
            }
            
            content
            pointsView
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
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("The monkey is")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
                
                Text("The middle distance shot off the tee.")
                    .font(.dmSans(size: 12, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .alignLeading()
            }
            
            Spacer(minLength: 0)
            
            scoringMenu
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
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            } else {
                ChipButton(text: "Select")
            }
        }
    }
    
    // MARK: - Points
    
    @ViewBuilder private var pointsView: some View {
        VStack(spacing: 8) {
            Text("Points")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            if scores.isEmpty {
                ForEach(roundSession.players, id: \.self) { player in
                    PlayerScoreRow(player: player, score: "-")
                }
            } else {
                ForEach(scores, id: \.self) { score in
                    if let player = roundSession.players.first(where: { $0.id == score.key }) {
                        PlayerScoreRow(player: player, score: "\(score.value)")
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
        .sorted(by: { $0.value > $1.value })
        
        printPretty(scores)
        
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

struct MonkeyPlayView_Previews: PreviewProvider {
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
        vm.sideGameSession.holes = [1, 2, 3, 4]
        vm.sideGameSession.monkey = MonkeySession(
            play: [1: "kyle", 2: "sarah", 3: "murphy", 4: "murphy"],
            skins: true
        )
        return vm
    }
    
    static var previews: some View {
        MonkeyPlayView(viewModel: viewModel, hole: 4)
            .environmentObject(roundSession)
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
