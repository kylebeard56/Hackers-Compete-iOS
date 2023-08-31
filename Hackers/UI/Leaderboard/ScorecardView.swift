//
//  ScorecardView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/30/23.
//

import SwiftUI

private enum Scoring { case gross, net }

struct ScorecardView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var players: [Player] = []
    
    @State private var showPlayerEditor: Bool = false
    @State private var showTeamStructure: Bool = false
    @State private var showHandicaps: Bool = false
    
    @State private var opacity: CGFloat = 1.0
    @State private var offset: CGFloat = 0.0
    
    @State private var scoring: Scoring = .net
    
    private var playerWidth: CGFloat {
        let w = players.compactMap({
            $0.name.width(usingFont: .dmSans(size: 15, weight: .bold))
        }).max() ?? 100
        return min(w + 20, 100)
    }
    private let hcpWidth: CGFloat = 60
    
    var body: some View {
        GeometryReader { geom in
            content
                .environmentObject(roundSession)
                .padding(.bottom, 10)
                .padding(.top, 20)
                .background(Color.systemViewBackground)
                .fullScreenCover(isPresented: $showPlayerEditor) {
                    EditPlayersView()
                }
                .fullScreenCover(isPresented: $showTeamStructure) {
                    TeamStructureView()
                }
                .fullScreenCover(isPresented: $showHandicaps) {
                    HandicapView()
                }
                .onChange(of: roundSession.players, perform: { s in print("onAppear \(geom.size.height)") })
        }
        .alignTop()
    }
    
    var content: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Scorecard")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 20)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    grid
                        .padding(.leading, 20)
                    
                    if roundSession.usingHandicaps {
                        HStack(spacing: 4) {
                            Text("Card shown with")
                                .font(.dmSans(size: 15, weight: .medium))
                                .foregroundColor(Color.systemGray)
                            
                            Button(action: {
                                scoring = (scoring == .net) ? .gross : .net
                                Haptics.fire(.light)
                            }) {
                                ChipButton(
                                    text: scoring == .net ? "net scoring" : "gross scoring",
                                    backgroundColor: colorScheme.superlightGray
                                )
                            }
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, 20)
                    }
                }
            }
//            Spacer(minLength: 0)
        }
        .onAppear() { self.players = roundSession.players }
        .onReceive(roundSession.$players, perform: { p in self.players = p })
    }
    
    // MARK: - Grid
    
    @ViewBuilder private var grid: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 20) {
                        ForEach(roundSession.holeRange, id: \.self) { h in
                            VStack(alignment: .center, spacing: 20) {
                                Text("\(h)")
                                    .font(.dmSans(size: 15, weight: .bold))
                                    .foregroundColor(Color.systemBlack)
                                
                                ForEach(0..<roundSession.players.count, id: \.self) { p in
                                    menu(for: p, on: h)
                                }
                            }
                        }
                        
                        Text("")
                    }
                    .padding(.leading, playerWidth + hcpWidth)
                    .background(ScrollGeometry(name: "scorecard", orientation: .horizontal))
                }
            }
            .coordinateSpace(name: "scorecard")
            .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in setScroll(for: v) })
            .alignTrailing()
            
            ZStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Hole")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .frame(width: hcpWidth, alignment: .leading)
                        .lineLimit(1)
                        .offset(x: -offset)
                    ForEach(players, id: \.self) { player in
                        let total = ScoreUtil.Stroke.computeTotal(
                            for: player,
                            over: roundSession.holeRange,
                            handicaps: scoring == .net
                        )
                        
                        ZStack {
                            Text("\(player.name)")
                                .font(.dmSans(size: 15, weight: .bold))
                                .foregroundColor(player.color.value)
                                .frame(width: playerWidth, height: 40, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .opacity(opacity)
                                .alignLeading()
                            
                            Text(total.toGolfScore)
                                .font(.dmSans(size: 15, weight: .bold))
                                .foregroundColor(player.color.value)
                                .frame(width: 40, height: 40, alignment: .center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .background(player.color.value.opacity(colorScheme.translucent))
                                .cornerRadius(6)
                                .alignTrailing()
                                .padding(.trailing, 20)
                        }
                        .frame(width: playerWidth + hcpWidth)
                    }
                }
            }
            .background(Color.systemViewBackground)
            .offset(x: offset)
            .alignLeading()
            
            LinearGradient(colors: [.systemBlack, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 8, height: shadowHeight)
                .padding(.leading, hcpWidth)
                .alignLeading()
                .opacity(opacity == 0 && colorScheme.isLight ? 0.03 : 0.00)
        }
    }
    
    // MARK: - Button
    
    private var editPlayersButton: some View {
        Button(action: {
            showPlayerEditor = true
            Haptics.fire(.light)
        }) {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    AwesomeImage(rawIcon: "f044".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    
                    Text("Edit players")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
//                    Text("Edit")
//                        .font(.dmSans(size: 15, weight: .medium))
//                        .foregroundColor(Color.systemGray)
                    
                    //AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 12, color: .systemBlack)
                    
                }
            }
        }
    }
    
    private var editTeamsButton: some View {
        Button(action: {
            showTeamStructure = true
            Haptics.fire(.light)
        }) {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    AwesomeImage(rawIcon: "f500".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    Text("\(roundSession.teams.isEmpty ? "Pick" : "Change") teams")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
                    //AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                }
            }
        }
    }
    
    private var handicapsButton: some View {
        Button(action: {
            showHandicaps = true
            Haptics.fire(.light)
        }) {
            VStack(spacing: 10) {
                HStack(spacing: 16) { //f868
                    AwesomeImage(rawIcon: "f303".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    Text("\(roundSession.usingHandicaps ? "Add" : "Adjust") handicaps")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
                    //AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                }
            }
        }
    }
    
    // MARK: - Scroll
    
    private func setScroll(for v: CGFloat) {
        if v < 0 {
            if v < -playerWidth {
                opacity = 0
                offset = -playerWidth
            } else {
                opacity = (1 - abs(v) * 1 / playerWidth)
                offset = min(v, playerWidth)
            }
        } else {
            opacity = 1
            offset = 0
        }
    }
    
    private var shadowHeight: CGFloat {
        return 20.0 + (60.0 * CGFloat(roundSession.players.count))
    }
    
    @ViewBuilder private func menu(for p: Int, on hole: Int) -> some View {
        let score = roundSession.players[p].score(for: hole, handicaps: scoring == .net)
        let label = score == .none ? "-" : "\(score.numericalValue)"

        Menu {
            Group {
                menuItem(for: .eagle, with: p, on: hole)
                menuItem(for: .birdie, with: p, on: hole)
                menuItem(for: .par, with: p, on: hole)
                menuItem(for: .bogey, with: p, on: hole)
                menuItem(for: .double, with: p, on: hole)
                menuItem(for: .triple, with: p, on: hole)
            }
            Menu("More") {
                menuItem(for: .albatross, with: p, on: hole)
                menuItem(for: .quad, with: p, on: hole)
                menuItem(for: .quin, with: p, on: hole)
                menuItem(for: .sex, with: p, on: hole)
            }
            if score != .none {
                Divider()
                menuItem(for: .none, with: p, on: hole)
            }
        } label: {
            Text(label)
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(score == .none ? colorScheme.lightGray : Color.systemBlack)
                .frame(width: 40, height: 40)
                .background(score == .none ? Color.clear : colorScheme.lightGray)
                .border(score == .none ? colorScheme.lightGray : Color.clear, width: 3, cornerRadius: 6)
                .cornerRadius(score.numericalValue < 0 ? 20 : 6)
        }
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    @ViewBuilder private func menuItem(for score: PlayerScore, with p: Int, on hole: Int) -> some View {
        Button(role: score == .none ? .destructive : .none, action: {
            Haptics.fire(.light)
            roundSession.players[p].score.updateValue(score.rawValue, forKey: hole)
        }) {
            Text(score == .none ? "Clear score" : score.menuName)
        }
    }
}

struct ScorecardView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var previews: some View {
        ScorecardView()
            .environmentObject(roundSession)
            .onAppear() {
                var kyle = kPlayerKyle
                kyle.score = [1: "bogey", 2: "birdie", 3: "bogey", 4: "double", 5: "par"]
                kyle.handicap = [1: 1, 2: 1, 3: 1, 4: 0, 5: 2]
                roundSession.holeRange = Array(1...18)
                roundSession.players = [kyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
            }
            .holisticPreview()
    }
}
