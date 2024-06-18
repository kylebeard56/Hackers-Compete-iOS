//
//  BankerView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/13/23.
//

import SwiftUI

struct BankerView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var outcomes: [GameScoreData] = []
    @State private var standings: [GameScoreData] = []
    @State private var bannerText: String = ""
    
    @State private var banker: String = ""
    @State private var wagers: [String: Int] = [:]
    @State private var presses: [String: Bool] = [:]
    @State private var parThree: Bool = false
    
    @State private var showSlider: Bool = false
    
    private var bankerPressed: Bool { presses[banker] ?? false }
    private var playerPressed: Bool { presses.filter({ $0.key != banker }).values.filter({ $0 }).count > 0 }
    
    private var verb: String {
        wagers.values.compactMap({ $0 }).count > 0 ? "Change" : "Set"
    }
    
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
            
            scoreTiles
            
            bankerSelectionRow
            
            if let bankerName = roundSession.players.first(where: { $0.id == banker })?.name {
                wagerView
                
                SmallButton(title: "\(verb) wagers with \(bankerName)", isDisabled: .false, isLoading: .false)
                .onTap {
                    self.showSlider = true
                }
            }
            parThreeToggle
        }
        .onAppear() {
            load(viewModel.sideGameSession.banker)
            compute()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            withAnimation(.easeOut(duration: 0.2)) {
                load(viewModel.sideGameSession.banker)
                compute()
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            compute()
        })
        /// Publish local changes back to current hole view model
        .onChange(of: banker, perform: { value in
            if viewModel.sideGameSession.banker?.banker[hole] != value {
                print("update banker from local change")
                viewModel.sideGameSession.banker?.banker.updateValue(value, forKey: hole)
                compute()
            }
        })
        .onChange(of: wagers, perform: { value in
            if viewModel.sideGameSession.banker?.wagers[hole] != value {
                print("update wagers from local change")
                viewModel.sideGameSession.banker?.wagers.updateValue(value, forKey: hole)
                compute()
            }
        })
        .onChange(of: presses, perform: { value in
            for p in roundSession.players {
                print("\(p.name) pressed? \(value[p.id] ?? false)")
            }
            if viewModel.sideGameSession.banker?.presses[hole] != value {
                print("update presses from local change")
                viewModel.sideGameSession.banker?.presses.updateValue(value, forKey: hole)
                compute()
            }
        })
        .onChange(of: parThree, perform: { value in
            if viewModel.sideGameSession.banker?.parThree[hole] != value {
                print("update par 3 from local change")
                viewModel.sideGameSession.banker?.parThree.updateValue(value, forKey: hole)
                compute()
            }
        })
        .sheet(isPresented: $showSlider) {
            WagerSliderView(viewModel: viewModel, hole: hole, bankerID: banker)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environmentObject(roundSession)
        }
    }
    
    private func load(_ banker: BankerSession?) {
        guard let s = banker else { return }
        self.banker = s.banker[hole] ?? ""
        self.wagers = s.wagers[hole] ?? [:]
        self.presses = s.presses[hole] ?? [:]
        self.parThree = s.parThree[hole] ?? false
        
        /// Set the banker to the winner of the last hole.
        if let h = viewModel.sideGameSession.holes.first,
           let x = roundSession.holeRange.firstIndex(of: h),
           let y = roundSession.holeRange.firstIndex(of: hole),
           y > x {
            let lastHoleOutcome = ScoreUtil.Match.computeScore(
                for: roundSession.players,
                on: hole - 1,
                handicaps: roundSession.usingHandicaps
            )
            if lastHoleOutcome != "tie" {
                self.banker = lastHoleOutcome
            }
        }
    }
    
    // MARK: - Banker row
    
    @ViewBuilder private var bankerSelectionRow: some View {
        HStack(spacing: 8) {
            scoringMenu
            
            if let p = roundSession.players.first(where: { $0.id == banker }), !banker.isEmpty {
                bankerPressButton(for: p)
            }
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
                banker = ""
            } label: {
                Text("Which player")
            }
            Divider()
            ForEach(roundSession.players, id: \.self) { p in
                Button {
                    Haptics.fire(.light)
                    banker = p.id
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
        HStack(spacing: 8) {
            if let player = roundSession.players.first(where: { $0.id == banker }) {
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
            
            let text = viewModel.sideGameSession.holes.first == hole ? "starts as" : "is the"
            Text("\(text) banker\(banker.isEmpty ? "?" : ".")")
                .font(.dmSans, size: 17, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Wagers & Presses
    
    @ViewBuilder private var wagerView: some View {
        VStack(spacing: 12) {
            Text("Wagers & presses")
                .font(.dmSans, size: 15, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            ForEach(roundSession.players.filter({ $0.id != banker }), id: \.self) { player in
                HStack(spacing: 12) {
                    Text(player.name)
                        .font(.dmSans, size: 15, weight: .bold)
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    

                    Group {
                        if let wager = wagers[player.id] {
                            Text("\(wager)")
                                .foregroundColor(Color.systemBlack)
                        } else {
                            Text("Wager")
                                .foregroundColor(Color.systemGray)
                        }
                    }
                    .font(.dmSans, size: 15, weight: .medium)
                    .frame(width: 48)
                    
                    pressButton(for: player)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    @ViewBuilder private func pressButton(for player: Player) -> some View {
        let isPressed = (self.presses[player.id] ?? false) || bankerPressed
        let forcePress = (self.presses[player.id] ?? false) && bankerPressed
        let pressValue = forcePress ? "\(parThree ? 9 : 4)x" : "\(parThree ? 3 : 2)x"
        
        Button(action: {
            if bankerPressed {
                Haptics.fire(.error)
                return
            }
            if let p = self.presses[player.id], p {
                self.presses.updateValue(false, forKey: player.id)
            } else {
                self.presses.updateValue(true, forKey: player.id)
            }
            Haptics.fire(.light)
        }) {
            if isPressed {
                Text(pressValue)
                    .font(.dmSans, size: 15, weight: .medium)
                    .foregroundColor(.white)
                    .frame(width: 64)
                    .padding(.vertical, 4)
                    .background(player.color.value)
                    .cornerRadius(4)
            } else {
                Text("Press")
                    .font(.dmSans, size: 15, weight: .medium)
                    .foregroundColor(player.color.value)
                    .frame(width: 64)
                    .padding(.vertical, 4)
                    .border(player.color.value, width: 2, cornerRadius: 4)
            }
        }
    }
    
    @ViewBuilder private func bankerPressButton(for b: Player) -> some View {
        let isPressedBack = self.presses[banker] ?? false
        Button(action: {
            if let p = self.presses[banker], p {
                self.presses.updateValue(false, forKey: banker)
            } else {
                self.presses.updateValue(true, forKey: banker)
            }
            Haptics.fire(.light)
        }) {
            if !playerPressed {
                Text("Press")
                    .font(.dmSans, size: 15, weight: .medium)
                    .foregroundColor(Color.systemGray2)
                    .padding(.vertical, 4)
                    .frame(width: 64)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .background(Color.systemGray6)
                    .cornerRadius(4)
            } else if bankerPressed {
                Text("Press")
                    .font(.dmSans, size: 15, weight: .medium)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .frame(width: 64)
                    .background(b.color.value)
                    .cornerRadius(4)
            } else {
                Text("Press")
                    .font(.dmSans, size: 15, weight: .medium)
                    .foregroundColor(b.color.value)
                    .padding(.vertical, 4)
                    .frame(width: 64)
                    .border(b.color.value, width: 2, cornerRadius: 4)
            }
        }
        .disabled(!playerPressed)
    }
    
    // MARK: - Points
    
    @ViewBuilder private var scoreTiles: some View {
        HStack(spacing: 10) {
            if standings.isEmpty {
                ForEach(roundSession.players, id: \.self) { player in
                    PlayerScoreTile(player: player, score: "0")
                }
            } else {
                ForEach(standings, id: \.self) { data in
                    if let player = roundSession.players.first(where: { $0.id == data.key }) {
                        if outcomes.isEmpty {
                            PlayerScoreTile(player: player, score: "\(data.value)")
                        } else if let v = outcomes.first(where: { $0.key == player.id })?.value {
                            PlayerScoreTile(
                                player: player,
                                score: "\(data.value)",
                                subtitle: "\(v >= 0 ? "Won" : "Lost") \(abs(v))"
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Skins
    
    @ViewBuilder private var parThreeToggle: some View {
        Toggle(isOn: $parThree, label: {
            VStack(spacing: 4) {
                Text("Par 3")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Text("Presses are 3x and must be called by the player while their ball is in flight.")
                    .font(.dmSans, size: 13, weight: .regular)
                    .foregroundColor(Color.systemGray)
                    .multilineTextAlignment(.leading)
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
        
        self.outcomes = ScoreUtil.Banker.computeScores(
            for: roundSession.players,
            playing: viewModel.sideGameSession.banker,
            on: hole,
            handicaps: roundSession.usingHandicaps
        ).sorted(by: {
            if $0.value == $1.value {
                return index(of: $1.key) > index(of: $0.key)
            } else {
                return $0.value > $1.value
            }
        })
    
        self.standings = ScoreUtil.Banker.computeTotal(
            for: roundSession.players,
            playing: viewModel.sideGameSession.banker,
            over: Array(range),
            on: hole,
            handicaps: roundSession.usingHandicaps
        ).sorted(by: {
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

struct BankerView_Previews: PreviewProvider {
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGame = .banker
        vm.sideGameSession.holes = [1, 2, 3, 4]
        vm.sideGameSession.banker = BankerSession(
            banker: [1: "kyle", 2: "sarah", 3: "murphy", 4: "pablo"],
            wagers: [
                1: ["sarah": 20, "murphy": 40, "pablo": 60],
                2: ["kyle": 20, "murphy": 40, "pablo": 60],
                3: ["sarah": 20, "kyle": 40, "pablo": 60],
                4: ["sarah": 20, "murphy": 40, "kyle": 60]
            ],
            presses: [
                1: ["kyle": false, "sarah": true, "murphy": false, "pablo": false],
                2: ["kyle": false, "sarah": false, "murphy": true, "pablo": false],
                3: ["kyle": true, "sarah": false, "murphy": false, "pablo": true],
                4: ["kyle": true, "sarah": true, "murphy": true, "pablo": true]
            ],
            parThree: [1: false, 2: true, 3: false, 4: false]
        )
        return vm
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        return rs
    }
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "par", 2: "par", 3: "birdie", 4: "par"]
        m.score = [1: "par", 2: "birdie", 3: "par", 4: "par"]
        p.score = [1: "birdie", 2: "par", 3: "par", 4: "birdie"]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        ScrollView {
            BankerView(viewModel: viewModel, hole: 1)
                .alignTop()
        }
        .environmentObject(roundSession)
        .padding(.horizontal, 20)
        .holisticPreview()
    }
}
