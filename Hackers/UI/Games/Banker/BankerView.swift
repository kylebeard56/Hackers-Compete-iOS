//
//  BankerView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/13/23.
//

import SwiftUI

/// Pick the banker on first tee, then it's auto-set as lowest net score from previous tee (select is tie w/ message).
/// The group sets a wager from 5-100 (increments of 5)
/// Show tile for tee order (banker tees last w/ order set from previous hole scores).
/// Players can press first, if one is TRUE, then banker can press back and double.

struct BankerView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var standings: [GameScoreData] = []
    @State private var bannerText: String = ""
    
    @State private var banker: String = ""
    @State private var wagers: [String: Int] = [:]
    @State private var presses: [String: Bool] = [:]
    @State private var parThree: Bool = false
    
    @State private var showSlider: Bool = false
    @State private var sliderID: String = ""
    
    private var bankerPressed: Bool { presses[banker] ?? false }
    private var playerPressed: Bool { presses.filter({ $0.key != banker }).values.filter({ $0 }).count > 0 }
    
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
            
            bankerSelectionRow
            if !banker.isEmpty {
                wagerView
            }
            parThreeToggle
            pointsView
        }
        .onAppear() {
            load(viewModel.sideGameSession.banker)
            compute()
        }
        /// Capture current hole view model changes for local display
        .onReceive(viewModel.$sideGameSession, perform: { sideGameSession in
            withAnimation(.easeOut(duration: 0.2)) {
                load(viewModel.sideGameSession.banker)
            }
        })
        .onReceive(roundSession.$players, perform: { _ in
            compute()
        })
        /// Publish local changes back to current hole view model
        .onChange(of: banker, perform: { value in
            viewModel.sideGameSession.banker?.banker.updateValue(banker, forKey: hole)
            compute()
        })
        .onChange(of: wagers, perform: { value in
            viewModel.sideGameSession.banker?.wagers.updateValue(value, forKey: hole)
            compute()
        })
        .onChange(of: presses, perform: { value in
            viewModel.sideGameSession.banker?.presses.updateValue(value, forKey: hole)
            compute()
        })
        .sheet(isPresented: $showSlider) {
            WagerSliderView(viewModel: viewModel, hole: hole, bankerID: banker, playerID: sliderID)
                .presentationDetents([.height(250)])
                .presentationDragIndicator(.visible)
                .environmentObject(roundSession)
        }
    }
    
    private func load(_ banker: BankerSession?) {
        guard let s = banker else { return }
        self.banker = s.banker[hole] ?? ""
        self.wagers = s.wagers[hole] ?? [:]
        self.presses = s.presses[hole] ?? [:]
    }
    
    // MARK: - Monkey row
    
    @ViewBuilder private var bankerSelectionRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("The banker is")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .alignLeading()
                    
                    if banker.isEmpty {
                        Group {
                            if viewModel.sideGameSession.holes.first == hole {
                                Text("Your party picks who starts.")
                            } else {
                                Text("Lowest score on last hole. Tiebreak goes to longest putt made.")
                            }
                        }
                        .font(.dmSans(size: 12, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .alignLeading()
                    }
                }
                
                Spacer(minLength: 0)
                
                scoringMenu
            }
            
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
                Text("Select")
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
        VStack {
            if let player = roundSession.players.first(where: { $0.id == banker }) {
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
    
    // MARK: - Wagers & Presses
    
    @ViewBuilder private var wagerView: some View {
        VStack(spacing: 12) {
            Text("Wagers & Presses")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            ForEach(roundSession.players.filter({ $0.id != banker }), id: \.self) { player in
                HStack(spacing: 12) {
                    Text(player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(player.color.value)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                    
                    wagerButton(for: player)
                    pressButton(for: player)
                }
            }
            
            // TODO: Text reminding players that all presses must happen before the banker tees (last). Banker must press before tee shot.
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    @ViewBuilder private func wagerButton(for player: Player) -> some View {
        Button(action: {
            self.sliderID = player.id
            self.showSlider = true
            Haptics.fire(.light)
        }) {
            Group {
                if let wager = wagers[player.id] {
                    Text("\(wager)")
                } else {
                    Text("Wager")
                }
            }
            .font(.dmSans(size: 15, weight: .medium))
            .foregroundColor(Color.systemBlack)
            .frame(width: 64)
            .padding(.vertical, 4)
            .background(Color.systemGray6)
        }
    }
    
    @ViewBuilder private func pressButton(for player: Player) -> some View {
        let isPressed = (self.presses[player.id] ?? false) || bankerPressed
        let forcePress = (self.presses[player.id] ?? false) && bankerPressed
        let pressValue = forcePress ? "\(parThree ? 6 : 4)x" : "\(parThree ? 3 : 2)x"
        
        Button(action: {
            self.presses.updateValue(!isPressed, forKey: player.id)
            Haptics.fire(.light)
        }) {
            if isPressed {
                Text(pressValue)
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 64)
                    .padding(.vertical, 4)
                    .background(player.color.value)
                    .cornerRadius(4)
            } else {
                Text("Press")
                    .font(.dmSans(size: 15, weight: .medium))
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
            self.presses.updateValue(!isPressedBack, forKey: banker)
            Haptics.fire(.light)
        }) {
            if !playerPressed {
                Text("Press back when someone presses you")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemGray3)
                    .padding(.vertical, 4)
                    .alignCenter()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .border(Color.systemGray5, width: 2, cornerRadius: 4)
            } else if bankerPressed {
                Text("Pressed back")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .alignCenter()
                    .background(b.color.value)
                    .cornerRadius(4)
            } else {
                Text("Press everyone back")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(b.color.value)
                    .padding(.vertical, 4)
                    .alignCenter()
                    .border(b.color.value, width: 2, cornerRadius: 4)
            }
        }
        .disabled(!playerPressed)
    }
    
    // MARK: - Points
    
    @ViewBuilder private var pointsView: some View {
        VStack(spacing: 8) {
            Text("Standings")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .alignLeading()
            
            if standings.isEmpty {
                ForEach(roundSession.players, id: \.self) { player in
                    PlayerScoreRow(player: player, score: "-")
                }
            } else {
                ForEach(standings, id: \.self) { score in
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
    
    @ViewBuilder private var parThreeToggle: some View {
        Toggle(isOn: $parThree, label: {
            VStack(spacing: 4) {
                Text("Par 3")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Text("Bets will become 3x and presses must be called while the player’s ball is in flight.")
                    .font(.dmSans(size: 13, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
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
        
//        self.scores = ScoreUtil.Monkey.computeTotal(
//            for: roundSession.players,
//            over: Array(range),
//            monkeys: viewModel.sideGameSession.monkey?.play ?? [:],
//            skins: skins,
//            handicaps: roundSession.usingHandicaps
//        )
//        .compactMap({ GameScoreData(key: $0.key, value: $0.value) })
//        .sorted(by: { $0.value > $1.value })
//
//        printPretty(scores)
//
//        self.bannerText = ScoreUtil.Monkey.banner(
//            for: roundSession.players,
//            over: viewModel.sideGameSession.holes,
//            for: hole,
//            monkeys: viewModel.sideGameSession.monkey?.play ?? [:],
//            skins: skins,
//            handicaps: roundSession.usingHandicaps
//        )
    }
}

struct BankerView_Previews: PreviewProvider {
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGameSession.holes = [1, 2, 3, 4]
        vm.sideGameSession.match = MatchSession(skins: true)
        return vm
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
//        rs.teams = ["Team one", "Team two"]
        return rs
    }
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.team = [:]
        s.team = [:]
        m.team = [:]
        p.team = [:]
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        m.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        p.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        
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
