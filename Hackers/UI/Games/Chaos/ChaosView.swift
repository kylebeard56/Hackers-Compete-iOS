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
    
    private let kHackersColors: [Color] = [
        Color.systemHackersPurple,
        Color.systemHackersYellow,
        Color.systemHackersGold,
        Color.systemHackersYellow
    ]
    
    var body: some View {
        VStack(spacing: 20) {
//            if let arr {
//                if arr == .team || arr == .combo {
//                    teamTile
//                }
//                if arr == .player || arr == .combo {
//                    playerTiles
//                }
//            }
            
            //playingCard
            
            floatingCard
//                .padding(.top, 20)
            
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
    
//    @ViewBuilder private var teamTile: some View {
//        let t = Player(id: "team", name: "Party")
//        if let rule = viewModel.chaosRuleMap[teamRule] {
//            tile2(for: t, with: rule)
//        } else {
//            tile2(for: t, with: Rule(), isLoading: true)
//        }
//    }
//    
//    @ViewBuilder private var playerTiles: some View {
////        let columns: [GridItem] = Array(repeating: GridItem(.flexible()), count: playerRules.count % 2 == 0 ? 2 : 1)
////        LazyVGrid(columns: columns, spacing: 10) {
////            if !playerRules.isEmpty {
////                ForEach(playerRules, id: \.self) { data in
////                    if let player = roundSession.players.first(where: { $0.id == data.key }) {
////                        tile2(for: player, for: viewModel.chaosRuleMap[data.value] ?? Rule())
////                    }
////                }
////            } else {
////                ForEach(roundSession.players, id: \.self) { player in
////                    loadingTile(for: player)
////                }
////            }
////        }
//        
//        if !playerRules.isEmpty {
//            ForEach(playerRules, id: \.self) { data in
//                if let player = roundSession.players.first(where: { $0.id == data.key }) {
//                    tile2(for: player, with: viewModel.chaosRuleMap[data.value] ?? Rule())
//                }
//            }
//        } else {
//                ForEach(roundSession.players, id: \.self) { player in
//                    tile2(for: player, with: Rule(), isLoading: true)
//                }
//        }
//    }
    
    @State private var hover = false
    @State private var flip = false
    
//    enum Quadrant: CaseIterable {
//        case topLeft, topRight, bottomLeft, bottomRight
//        
//        var startPoint: UnitPoint {
//            switch self {
//            case .topLeft:      return .bottomTrailing
//            case .topRight:     return .bottomLeading
//            case .bottomLeft:   return .topTrailing
//            case .bottomRight:  return .topLeading
//            }
//        }
//        
//        var endPoint: UnitPoint {
//            switch self {
//            case .topLeft:      return .topLeading
//            case .topRight:     return .topTrailing
//            case .bottomLeft:   return .bottomLeading
//            case .bottomRight:  return .bottomTrailing
//            }
//        }
//        
//        var verticalEdge: Edge.Set {
//            switch self {
//            case .topLeft:      return .top
//            case .topRight:     return .top
//            case .bottomLeft:   return .bottom
//            case .bottomRight:  return .bottom
//            }
//        }
//        
//        var horizontalEdge: Edge.Set {
//            switch self {
//            case .topLeft:      return .leading
//            case .topRight:     return .trailing
//            case .bottomLeft:   return .leading
//            case .bottomRight:  return .trailing
//            }
//        }
//        
//        var verticalPad: CGFloat {
//            switch self {
//            case .topLeft:      return 100
//            case .topRight:     return 100
//            case .bottomLeft:   return 130
//            case .bottomRight:  return 130
//            }
//        }
//        
//        var horizontalPad: CGFloat {
//            switch self {
//            case .topLeft:      return 60
//            case .topRight:     return 60
//            case .bottomLeft:   return 60
//            case .bottomRight:  return 60
//            }
//        }
//        
//        var animationX: CGFloat {
//            switch self {
//            case .topLeft:      return -20
//            case .topRight:     return 20
//            case .bottomLeft:   return -20
//            case .bottomRight:  return 20
//            }
//        }
//        
//        var animationY: CGFloat {
//            switch self {
//            case .topLeft:      return -20
//            case .topRight:     return -20
//            case .bottomLeft:   return 20
//            case .bottomRight:  return 20
//            }
//        }
//    }
//    
//    @State private var drift: Bool = false
//    
//    @ViewBuilder private func sparkleIcon(
//        with color: Color,
//        colors: [Color],
//        quadrant: Quadrant
//    ) -> some View {
//        let icon = Icon(name: "e5d6", size: 11, weight: .solid)
//            .foregroundStyle(
//                hover
//                ? colors[safe: Int.random(in: 0..<colors.count)] ?? color
//                : color
//            )
//            .opacity(drift ? 0 : 1)
//            .offset(x: drift ? quadrant.animationX : 0, y: drift ? quadrant.animationY : 0)
//            .animation(
//                .easeInOut(duration: 2)
//                .delay( CGFloat(2 / Double(Int.random(in: 2...8)) ) )
//                .repeatForever(autoreverses: false),
//                value: hover
//            )
//            .animation(
//                .easeInOut(duration: 4)
//                .delay( CGFloat(2 / Double(Int.random(in: 2...8)) ) ),
//                //.repeatForever(),
//                value: drift
//            )
//        
//        if quadrant == .topLeft {
//            icon
//                .alignTop()
//                .alignLeading()
//        } else if quadrant == .topRight {
//            icon
//                .alignTop()
//                .alignTrailing()
//        } else if quadrant == .bottomLeft {
//            icon
//                .alignBottom()
//                .alignLeading()
//        } else if quadrant == .bottomRight {
//            icon
//                .alignBottom()
//                .alignTrailing()
//        }
//    }
    
//    @ViewBuilder private func sparklingGradient(for player: Player, quadrant: Quadrant) -> some View {
//        let color = player.color.value
//        let colors = roundSession.players.filter({ $0.id != player.id }).compactMap({ $0.color.value }) + Array(repeating: Color.systemHackersGold, count: 3)
//        
//        if let player = roundSession.players[safe: 0] {
//            ZStack {
//                Rectangle()
//                    .fill(
//                        LinearGradient(
//                            colors: [color.opacity(0.4), Color.clear],
//                            startPoint: quadrant.startPoint,
//                            endPoint: quadrant.endPoint)
//                    )
//                    .blur(radius: 20)
//                
////                Icon(name: "e5d6", size: 13, weight: .solid)
////                    .foregroundStyle(
////                        hover 
////                        ? colors[safe: Int.random(in: 0..<colors.count)] ?? color
////                        : colors[safe: Int.random(in: 0..<colors.count)] ?? color
////                    )
////                    .opacity(hover ? 1 : 0)
////                    .animation(
////                        .easeInOut(duration: 1.25).repeatForever(),
////                        value: hover
////                    )
//                
////                sparkleIcon(with: color, colors: colors, quadrant: quadrant, delay: 0)
////                    .padding(quadrant.verticalPad, 135)
////                    .padding(quadrant.horizontalPad, 45)
////                
////                sparkleIcon(with: color, colors: colors, quadrant: quadrant, delay: 0)
////                    .padding(quadrant.verticalPad, 90)
////                    .padding(quadrant.horizontalPad, 30)
//                
////                sparkleIcon(with: color, colors: colors, quadrant: quadrant)
////                    .padding(quadrant.verticalEdge, quadrant.verticalPad)
////                    .padding(quadrant.horizontalEdge, quadrant.horizontalPad + 15)
////                
////                sparkleIcon(with: color, colors: colors, quadrant: quadrant)
////                    .padding(quadrant.verticalEdge, quadrant.verticalPad)
////                    .padding(quadrant.horizontalEdge, quadrant.horizontalPad)
////                
////                sparkleIcon(with: color, colors: colors, quadrant: quadrant)
////                    .padding(quadrant.verticalEdge, quadrant.verticalPad + 15)
////                    .padding(quadrant.horizontalEdge, quadrant.horizontalPad)
//                
////                sparkleIcon(with: color, colors: colors, quadrant: quadrant, delay: 1.25 / 1.5)
////                    .padding(quadrant.verticalPad, 30)
////                    .padding(quadrant.horizontalPad, 90)
////                
////                sparkleIcon(with: color, colors: colors, quadrant: quadrant, delay: 1.25 / 1.5)
////                    .padding(quadrant.verticalPad, 45)
////                    .padding(quadrant.horizontalPad, 135)
//                
////                Icon(name: "e5d6", size: 13, weight: .solid)
////                    .foregroundStyle(
////                        hover
////                        ? colors[safe: Int.random(in: 0..<colors.count)] ?? color
////                        : colors[safe: Int.random(in: 0..<colors.count)] ?? color
////                    )
////                    .opacity(hover ? 0 : 1)
////                    .animation(
////                        .easeInOut(duration: 1.25).repeatForever(),
////                        value: hover
////                    )
////                    .padding(quadrant.verticalPad, 30)
////                    .padding(quadrant.horizontalPad, 30)
////                    .alignLeading()
////                    .alignTop()
////                
////                Icon(name: "e5d6", size: 13, weight: .solid)
////                    .foregroundStyle(
////                        hover
////                        ? colors[safe: Int.random(in: 0..<colors.count)] ?? color
////                        : colors[safe: Int.random(in: 0..<colors.count)] ?? color
////                    )
////                    .opacity(hover ? 1 : 0)
////                    .animation(
////                        .easeInOut(duration: 1.25).repeatForever(),
////                        value: hover
////                    )
////                    .padding(quadrant.verticalPad, 30)
////                    .padding(quadrant.horizontalPad, 60)
////                    .alignLeading()
////                    .alignTop()
//            }
//        }
//    }
    
//    @State private var twinkle: [Bool] = Array(repeating: false, count: 8)
    
//    @ViewBuilder private var twinkleAnimation: some View {
//        let ratio: CGFloat = 350 / 490 // Size of image
//        let h: CGFloat = UIScreen.main.bounds.height / 3
//        let w: CGFloat = ratio * h
//        
//        let stepW: CGFloat = (w / 2.0 - 20.0) / CGFloat(twinkle.count)
//        let stepH: CGFloat = (h / 2.0 - 20.0) / CGFloat(twinkle.count)
//        
//        ForEach(0..<twinkle.count, id: \.self) { i in
//            Icon(name: "e5d6", size: 15, weight: .solid)
//                .foregroundStyle(Color.systemHackersYellow)
//                .opacity(twinkle[i] ? 0 : 1)
//                .scaleEffect(twinkle[i] ? 0.4 : 1)
//                .animation(
//                    .easeOut(duration: 3).delay(CGFloat(i / 3)).repeatForever(),
//                    value: twinkle[i]
//                )
//                .position(
//                    x: CGFloat(i * stepW),
//                    y: CGFloat(i * stepH)
//                )
//                .onAppear() {
//                    twinkle[i] = true
//                }
//        }
//    }
    
    @ViewBuilder private var floatingCard: some View {
        let ratio: CGFloat = 350 / 490 // Size of image
        let w: CGFloat = UIScreen.main.bounds.width * 0.8
        let h: CGFloat = 1 / ratio * w
        
        ZStack {
            VStack(spacing: 20) {
//                Text("Tap card to reveal")
//                    .font(.dmSans, size: 13, weight: .bold)
//                    .frame(height: 13)
//                    .foregroundStyle(
//                        LinearGradient(
//                            colors: hover ? [.blue, .green] : [.purple, .pink],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
//                    .animation(
//                        .easeInOut(duration: 1.25).repeatForever(),
//                        value: hover
//                    )
//                    .alignCenter()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        flip = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                        showRuleDetail = true
                        flip = false
                    })
                    Haptics.fire(.light)
                }) {
                    Image(uiImage: Asset.Images.playingCard.image)
                        .interpolation(.high)
                        .resizable()
                        .scaledToFit()
                        .frame(height: h)
//                        .offset(y: hover ? -5 : 5)
//                        .animation(
//                            .easeInOut(duration: 2.5).repeatForever(),
//                            value: hover
//                        )
//                        .shadow(
//                            color: hover ? Color.systemHackersGold.opacity(0.2) : Color.systemBlack.opacity(0.2),
//                            radius: 12,
//                            x: 0,
//                            y: 0
//                        )
                        .rotation3DEffect(.degrees(flip ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                }
            }

            TwinkleAnimationView(colors: roundSession.players.compactMap({ $0.color.value }) + kHackersColors)
                .frame(width: w, height: h)
        }
        .onAppear {
            self.hover.toggle()
        }
    }
    
//    @ViewBuilder private var playingCard: some View {
//        let pad = (UIScreen.main.bounds.width - 40) * 1.4 / 4 // Computes 1/4th height of card
//        Button(action: {
//            showRuleDetail = true
//            Haptics.fire(.light)
//        }) {
//            ZStack {
//                Image(uiImage: Asset.Images.playingCard.image)
//                    .interpolation(.high)
//                    .resizable()
//                    .scaledToFit()
//                    .grayscale(1)
//                
//                Text("Reveal cards")
//                    .font(.dmSans, size: 15, weight: .bold)
//                    .foregroundStyle(Color.white)
//                    .alignCenter()
//                    .frame(width: 120, height: 40)
//                    .background(Color.systemHackersPurple)
//                    .cornerRadius(30)
//                    .shadow(color: Color.systemBlack.opacity(0.16), radius: 8, x: 0, y: 0)
//                    .padding(.bottom, pad)
//                    .alignBottom()
//            }
//        }
//    }
    
//    @ViewBuilder private func tile2(for p: Player, with r: Rule, isLoading: Bool = false) -> some View {
//        let color = p.id == "team" ? Color.systemHackersPurple : p.color.value
//        
//        Button(action: {
//            if isLoading { return }
//            if r.id.isEmpty {
//                Task { await viewModel.reloadChaosRules() }
//            } else {
//                roundSession.chaosTab = p.id
//                showRuleDetail = true
//            }
//            
//            Haptics.fire(.light)
//        }) {
//            HStack(spacing: 20) {
////                ZStack {
////                    Circle()
////                        .fill(color.opacity(colorScheme.translucent * 2.0))
////                        .frame(width: 48, height: 48)
////                    AwesomeImage(
////                        rawIcon: r.icon.unicode,
////                        style: .regular,
////                        size: 24,
////                        color: color
////                    )
////                }
//                
//                AwesomeImage(
//                    rawIcon: r.icon.unicode,
//                    style: .regular,
//                    size: 22,
//                    color: color
//                )
//                
//                HStack {
//                    VStack(spacing: 0) {
//                        if !isLoading {
//                            Text(r.name)
//                                .font(.dmSans, size: 11, weight: .medium)
//                                .foregroundColor(Color.systemBlack)
//                                .alignLeading()
//                        }
//                        
//                        Text(p.name)
//                            .font(.dmSans, size: 18, weight: .bold)
//                            .foregroundColor(color)
//                            .alignLeading()
//                    }
//                    
//                    Spacer(minLength: 0)
//                    
//                    if isLoading {
//                        ProgressView()
//                            .progressViewStyle(.circular)
//                            .tint(Color.systemBlack)
//                    }
//                }
//                
////                VStack(spacing: 4) {
////                    HStack {
////                        Text(p.name)
////                            .foregroundColor(color)
////                            .font(.dmSans, size: 20, weight: .bold)
////                            .lineLimit(1)
////                            .minimumScaleFactor(0.75)
////                        
////                        Spacer(minLength: 10)
////                        
////                        if isLoading {
////                            ProgressView()
////                                .progressViewStyle(.circular)
////                                .tint(Color.systemBlack)
////                        }
////                    }
////
////                    if !isLoading {
////                        Text(r.name)
////                            .foregroundColor(Color.systemBlack)
////                            .font(.dmSans, size: 13, weight: .medium)
////                            .multilineTextAlignment(.leading)
////                            .lineLimit(2)
////                            .minimumScaleFactor(0.85)
////                            .alignLeading()
////                    }
////                }
//            }
//            .padding(.horizontal, 16)
//            .padding(.vertical, 12)
//            .background(
//                color.opacity(colorScheme.translucent)
//                //Color.systemCard
//            )
//            //.border(color, width: 3, cornerRadius: 12)
//            .cornerRadius(12)
//        }
//    }
//    
//    @ViewBuilder private func tile(for player: Player, for r: Rule) -> some View {
//        let color = player.id == "team" ? Color.systemBlack : player.color.value
//        Button(action: {
//            if r.id.isEmpty {
//                Task { await viewModel.reloadChaosRules() }
//            } else {
//                roundSession.chaosTab = player.id
//                showRuleDetail = true
//            }
//            
//            Haptics.fire(.light)
//        }) {
//            VStack(spacing: 4) {
//                if r.icon.isEmpty {
//                    Circle()
//                        .stroke(color, lineWidth: 2)
//                        .frame(width: 20, height: 20)
//                        .alignCenter()
//                } else {
//                    AwesomeImage(rawIcon: r.icon.unicode, style: .regular, size: 20, color: color)
//                        .alignCenter()
//                }
//
//                Text(r.id.isEmpty ? "Tap to load" : player.name)
//                    .font(.dmSans, size: 17, weight: .bold)
//                    .foregroundColor(color)
//                    .minimumScaleFactor(0.75)
//                    .lineLimit(1)
//                    .alignCenter()
//            }
//            .padding(.vertical, 12)
//            .padding(.horizontal, 16)
//            .background(
//                (player.id == "team" ? Color.systemHackersPurple : player.color.value).opacity(colorScheme.translucent)
//            )
//            .cornerRadius(8)
//        }
//    }
//    
//    @ViewBuilder private func loadingTile(for player: Player) -> some View {
//        let color = player.id == "team" ? Color.systemBlack : player.color.value
//        VStack(spacing: 4) {
//            ProgressView()
//                .progressViewStyle(.circular)
//                .tint(color)
//                .alignCenter()
//            Text(player.name)
//                .font(.dmSans, size: 17, weight: .bold)
//                .foregroundColor(color)
//                .minimumScaleFactor(0.75)
//                .lineLimit(1)
//                .alignCenter()
//        }
//        .padding(.vertical, 12)
//        .padding(.horizontal, 16)
//        .background(
//            (player.id == "team" ? Color.systemHackersPurple : player.color.value).opacity(colorScheme.translucent)
//        )
//        .cornerRadius(8)
//    }
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
        
        return [k, s, m, p]
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

struct TwinkleAnimationView: View {
    var colors: [Color] = [.blue, .green, .purple, .indigo, .pink, .orange]
    
    @State private var stars: [StarProperties] = []
    @State private var angle: Angle = .zero
    
    // We will animate following properties of Star Shape
    struct StarProperties: Identifiable {
        let id = UUID()
        let position: CGPoint
        var scale: CGFloat = 1.0
        var opacity: Double = 1.0
        var hue: Angle = .zero
    }
    
    // Lets jump to body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // We'll add a Gradient to give a good bg effect
                RoundedRectangle(cornerRadius: 0)
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: colors),
                            center: .top,
                            angle: angle
                        )
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 24)
                    .opacity(0.2)
                    .animation(
                        .easeInOut(duration: 5.0).repeatForever(),
                        value: angle
                    )
                
                let randomFrame = CGFloat.random(in: 0...20)
                
                ForEach(stars) { star in
                    Star()
                        .fill(colors[Int.random(in: 0..<colors.count)])
                        .frame(width: randomFrame, height: randomFrame)
                        .scaleEffect(star.scale)
                        .opacity(star.opacity)
                        .position(star.position)
                        .hueRotation(star.hue)
                        .blur(radius: star.opacity)
                        .animation(
                            .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                        )
                }
                
            }
            .onAppear {
                // Lets animate our Gradient
                withAnimation(Animation.easeInOut(duration: 0.5)) {
                    self.angle = .degrees(360)
                }
                
                startAnimatingStars(in: geometry.size)
            }
        }
    }

    private func startAnimatingStars(in size: CGSize) {
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            
            let randomX = CGFloat.random(in: 0...size.width)
            let randomY = CGFloat.random(in: 0...size.height)
            let randomHue = Angle(degrees: Double(CGFloat.random(in: 0...360)))
            
            let newStar = StarProperties(position: CGPoint(x: randomX, y: randomY))
            stars.append(newStar)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let index = stars.firstIndex(where: { $0.id == newStar.id }) {
                    stars[index].scale = 2.0
                    stars[index].opacity = 0.0
                    stars[index].hue = randomHue
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                stars.removeAll(where: { $0.id == newStar.id })
            }
        }
        
        /// stop the timer after a certain duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
            timer.invalidate()
        }
    }
}

struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        let (x, y, width, height) = rect.centeredSquare.flatten()
        let lowerPoint = CGPoint(x: x + width / 2, y: y + height)
        
        let path = Path { p in
            p.move(to: lowerPoint)
            p.addArc(center: CGPoint(x: x, y: (y + height)),
                     radius: (width / 2),
                     startAngle: .A360,
                     endAngle: .A270,
                     clockwise: true)
            p.addArc(center: CGPoint(x: x, y: y),
                     radius: (width / 2),
                     startAngle: .A90,
                     endAngle: .zero,
                     clockwise: true)
            
            p.addArc(center: CGPoint(x: x + width, y: y),
                     radius: (width / 2),
                     startAngle: .A180,
                     endAngle: .A90,
                     clockwise: true)

            p.addArc(center: CGPoint(x: x + width, y: y + height),
                     radius: (width / 2),
                     startAngle: .A270,
                     endAngle: .A180,
                     clockwise: true)
        }
        
        return path
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: self.midX, y: self.midY)
    }
    
    var centeredSquare: CGRect {
        let width = ceil(min(size.width, size.height))
        let height = width
        
        let newOrigin = CGPoint(x: origin.x + (size.width - width) / 2, y: origin.y + (size.height - height) / 2)
        let newSize = CGSize(width: width, height: height)
        return CGRect(origin: newOrigin, size: newSize)
    }
    
    func flatten() -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        return (origin.x, origin.y, size.width, size.height)
    }
}

extension Angle {
    static let A180 = Angle(radians: .pi)
    static let A90 = Angle(radians: .pi / 2)
    static let A270 = Angle(radians: (.pi / 2) * 3)
    static let A360 = Angle(radians: .pi * 2)
}
