//
//  ChaosView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct ChaosData: Hashable, Codable {
    var id: String = UUID().uuidString
    var key: String = ""
    var value: String = ""
}

struct ChaosView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    @Binding var hole: Int
    
    @State private var teamRule: String = ""
    @State private var playerRules: [ChaosData] = []
    @State private var playingThru: Bool = false
    
    @State private var showRuleDetail: Bool = false
    @State private var showRuleModifier: Bool = false
    
    @State private var arr: ChaosCardsArrangement?
    
    var body: some View {
        VStack(spacing: 10) {
//            if let arr {
//                if arr == .team || arr == .combo {
//                    teamTile
//                }
//                if arr == .player || arr == .combo {
//                    playerTiles
//                }
//            }
            
            playingCard
            
            SmallButton(
                title: "Modify rules",
                foregroundColor: Color.systemWhite,
                backgroundColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false
            )
            .onTap {
                showRuleModifier = true
            }
        }
        .task {
            print("task ChaosRules for hole \(hole)")
            if viewModel.chaosRules.isEmpty {
                await viewModel.reloadChaosRules()
            }
            await viewModel.attemptDraw(for: roundSession.players, on: hole)
            self.buildRules(viewModel.sideGameSession)
        }
        .onChange(of: hole, perform: { h in
            Task {
                await viewModel.attemptDraw(for: roundSession.players, on: h)
                self.buildRules(viewModel.sideGameSession)
            }
        })
        .onReceive(viewModel.$sideGameSession, perform: { s in
            /// Minor delay to prevent random race condition... unsure this actually helps.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: {
                self.buildRules(s)
            })
        })
        .onReceive(HackersNotification.refreshChaosRules.publisher(), perform: { _ in
            Task {
                print("HackersNotification refreshChaosRules")
                await viewModel.reloadChaosRules()
            }
        })
        .sheet(isPresented: $showRuleDetail) {
            ChaosRuleDetailView(viewModel: viewModel, hole: hole)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showRuleModifier) {
            ChaosModifyRulesView(viewModel: viewModel, hole: hole)
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }
    
    private func buildRules(_ s: SideGameSession) {
        guard let chaos = s.chaos else { return }
        
        print("\(#function) on hole \(hole)")
        printPretty(chaos)
        
        arr = ChaosCardsArrangement(rawValue: chaos.arrangement)
        teamRule = chaos.teamRule[hole] ?? ""
        playerRules = chaos.playerRules
            .compactMap { ChaosData(key: $0.key, value: $0.value[hole] ?? "") }
            .sorted(by: {
                let p = roundSession.players
                let id1 = $0.key
                let id2 = $1.key
                return p.firstIndex(where: { $0.id == id1 }) ?? 99 < p.firstIndex(where: { $0.id == id2 }) ?? 99
            })
        
        print("playerRules \(playerRules)")
        print("chaos rule map \(viewModel.chaosRuleMap.count)")
    }
    
    @ViewBuilder private var teamTile: some View {
        let t = Player(id: "team", name: "Party")
        if let rule = viewModel.chaosRuleMap[teamRule] {
            tile2(for: t, with: rule)
        } else {
            tile2(for: t, with: Rule(), isLoading: true)
        }
    }
    
    @ViewBuilder private var playerTiles: some View {
//        let columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: playerRules.count % 2 == 0 ? 2 : 1)
//        LazyVGrid(columns: columns, spacing: 10) {
//            if !playerRules.isEmpty {
//                ForEach(playerRules, id: \.self) { data in
//                    if let player = roundSession.players.first(where: { $0.id == data.key }) {
//                        tile2(for: player, for: viewModel.chaosRuleMap[data.value] ?? Rule())
//                    }
//                }
//            } else {
//                ForEach(roundSession.players, id: \.self) { player in
//                    loadingTile(for: player)
//                }
//            }
//        }
        
        if !playerRules.isEmpty {
            ForEach(playerRules, id: \.self) { data in
                if let player = roundSession.players.first(where: { $0.id == data.key }) {
                    tile2(for: player, with: viewModel.chaosRuleMap[data.value] ?? Rule())
                }
            }
        } else {
                ForEach(roundSession.players, id: \.self) { player in
                    tile2(for: player, with: Rule(), isLoading: true)
                }
        }
    }
    
    @ViewBuilder private var playingCard: some View {
        let pad = (UIScreen.main.bounds.width - 40) * 1.4 / 4 // Computes 1/4th height of card
        Button(action: {
            showRuleDetail = true
            Haptics.fire(.light)
        }) {
            ZStack {
                Image(uiImage: Asset.Images.playingCard.image)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                
                Text("Reveal cards")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundStyle(Color.white)
                    .alignCenter()
                    .frame(width: 120, height: 40)
                    .background(Color.systemHackersPurple)
                    .cornerRadius(30)
                    .shadow(color: Color.systemBlack.opacity(0.16), radius: 8, x: 0, y: 0)
                    .padding(.bottom, pad)
                    .alignBottom()
            }
        }
        
//        let width = UIScreen.main.bounds.width - 40
//        let height = width * 1.6
//        
//        ZStack {
//            Color.systemCard
//
//            Image(uiImage: Asset.Images.cardPattern.image)
//                .interpolation(.high)
//                .resizable()
//                .padding(70)
//            
//            RoundedRectangle(cornerRadius: 20)
//                .stroke(Color.systemHackersGreen, lineWidth: 3)
//            
//            RoundedRectangle(cornerRadius: 0)
//                .stroke(Color.systemHackersGreen, lineWidth: 5)
//                .padding(30)
//            
//            RoundedRectangle(cornerRadius: 0)
//                .stroke(Color.systemHackersGreen, lineWidth: 3)
//                .padding(70)
//            
//            RoundedRectangle(cornerRadius: 0)
//                .fill(Color.systemCard)
//                .frame(height: 120)
//                .padding(120)
//            
//            RoundedRectangle(cornerRadius: 0)
//                .stroke(Color.systemHackersGreen, lineWidth: 3)
//                .frame(height: 120)
//                .padding(120)
//            
//            Image(uiImage: Asset.Images.logoGreen.image)
//                .interpolation(.high)
//                .resizable()
//                .scaledToFit()
//                .padding(130)
//        }
    }
    
    @ViewBuilder private func tile2(for p: Player, with r: Rule, isLoading: Bool = false) -> some View {
        let color = p.id == "team" ? Color.systemHackersPurple : p.color.value
        
        Button(action: {
            if isLoading { return }
            if r.id.isEmpty {
                Task { await viewModel.reloadChaosRules() }
            } else {
                roundSession.chaosTab = p.id
                showRuleDetail = true
            }
            
            Haptics.fire(.light)
        }) {
            HStack(spacing: 20) {
//                ZStack {
//                    Circle()
//                        .fill(color.opacity(colorScheme.translucent * 2.0))
//                        .frame(width: 48, height: 48)
//                    AwesomeImage(
//                        rawIcon: r.icon.unicode,
//                        style: .regular,
//                        size: 24,
//                        color: color
//                    )
//                }
                
                AwesomeImage(
                    rawIcon: r.icon.unicode,
                    style: .regular,
                    size: 22,
                    color: color
                )
                
                HStack {
                    VStack(spacing: 0) {
                        if !isLoading {
                            Text(r.name)
                                .font(.dmSans, size: 11, weight: .medium)
                                .foregroundColor(Color.systemBlack)
                                .alignLeading()
                        }
                        
                        Text(p.name)
                            .font(.dmSans, size: 18, weight: .bold)
                            .foregroundColor(color)
                            .alignLeading()
                    }
                    
                    Spacer(minLength: 0)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.systemBlack)
                    }
                }
                
//                VStack(spacing: 4) {
//                    HStack {
//                        Text(p.name)
//                            .foregroundColor(color)
//                            .font(.dmSans, size: 20, weight: .bold)
//                            .lineLimit(1)
//                            .minimumScaleFactor(0.75)
//                        
//                        Spacer(minLength: 10)
//                        
//                        if isLoading {
//                            ProgressView()
//                                .progressViewStyle(.circular)
//                                .tint(Color.systemBlack)
//                        }
//                    }
//
//                    if !isLoading {
//                        Text(r.name)
//                            .foregroundColor(Color.systemBlack)
//                            .font(.dmSans, size: 13, weight: .medium)
//                            .multilineTextAlignment(.leading)
//                            .lineLimit(2)
//                            .minimumScaleFactor(0.85)
//                            .alignLeading()
//                    }
//                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                color.opacity(colorScheme.translucent)
                //Color.systemCard
            )
            //.border(color, width: 3, cornerRadius: 12)
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder private func tile(for player: Player, for r: Rule) -> some View {
        let color = player.id == "team" ? Color.systemBlack : player.color.value
        Button(action: {
            if r.id.isEmpty {
                Task { await viewModel.reloadChaosRules() }
            } else {
                roundSession.chaosTab = player.id
                showRuleDetail = true
            }
            
            Haptics.fire(.light)
        }) {
            VStack(spacing: 4) {
                if r.icon.isEmpty {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 20, height: 20)
                        .alignCenter()
                } else {
                    AwesomeImage(rawIcon: r.icon.unicode, style: .regular, size: 20, color: color)
                        .alignCenter()
                }

                Text(r.id.isEmpty ? "Tap to load" : player.name)
                    .font(.dmSans, size: 17, weight: .bold)
                    .foregroundColor(color)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .alignCenter()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                (player.id == "team" ? Color.systemHackersPurple : player.color.value).opacity(colorScheme.translucent)
            )
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder private func loadingTile(for player: Player) -> some View {
        let color = player.id == "team" ? Color.systemBlack : player.color.value
        VStack(spacing: 4) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(color)
                .alignCenter()
            Text(player.name)
                .font(.dmSans, size: 17, weight: .bold)
                .foregroundColor(color)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .alignCenter()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            (player.id == "team" ? Color.systemHackersPurple : player.color.value).opacity(colorScheme.translucent)
        )
        .cornerRadius(8)
    }
}

struct ChaosView_Previews: PreviewProvider {
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo

        k.team = [:]
        s.team = [:]
        m.team = [:]
        p.team = [:]
        
        k.score = [1: "par"]
        s.score = [1: "par"]
        m.score = [1: "par"]
        p.score = [1: "par"]
        
        return [k, s, m]
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        return rs
    }
    
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGameSession.holes = [1, 2, 3]
        vm.sideGameSession.monkey = MonkeySession(
            play: [1: "kyle", 2: "sarah", 3: "murphy", 4: "murphy"],
            skins: true
        )
        return vm
    }
    
    static var previews: some View {
        ChaosView(viewModel: viewModel, hole: .constant(4))
            .environmentObject(AppSession())
            .environmentObject(roundSession)
            .padding(.horizontal, 20)
            .padding(.vertical, 80)
            .holisticPreview()
    }
}
