//
//  ScorecardView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/30/23.
//

import SwiftUI

/**
 
 Names at top with initial and color
 holes down edge with hcp
 filter for holes shiown by order or diffuculty
 sticky final score at bottom
 if teams, show team sums down the line too
 
 */
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
    
    @State private var useHCP: Bool = true
    
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
                    .font(.dmSans, size: 20, weight: .bold)
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
                        HandicapComputationToggle(useHCP: $useHCP)
                            .padding(.leading, 20)
                    }
                }
            }
        }
        .onAppear() { self.players = roundSession.players }
        .onReceive(roundSession.$players, perform: { p in self.players = p })
    }
    
    // MARK: - Grid
    
    @ViewBuilder private var grid: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 0) {
                        Spacer().frame(width: 4)
                        
                        ForEach(roundSession.holeRange, id: \.self) { h in
                            VStack(alignment: .center, spacing: 20) {
                                Text("\(h)")
                                    .font(.dmSans, size: 15, weight: .bold)
                                    .foregroundColor(
                                        roundSession.scoringExists(for: h) ? Color.systemBlack : Color.systemGray
                                    )
                                
                                ForEach(0..<roundSession.players.count, id: \.self) { p in
                                    menu(for: p, on: h)
                                }
                            }
                            .padding(.trailing, 20)
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
                        .font(.dmSans, size: 15, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .frame(width: hcpWidth, alignment: .leading)
                        .lineLimit(1)
                        .offset(x: -offset)
                    ForEach(players, id: \.self) { player in
                        let total = ScoreUtil.Stroke.computeTotal(
                            for: player,
                            over: roundSession.holeRange,
                            handicaps: useHCP
                        )
                        
                        ZStack {
                            Text("\(player.name)")
                                .font(.dmSans, size: 15, weight: .bold)
                                .foregroundColor(player.color.value)
                                .frame(width: playerWidth, height: 40, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .opacity(opacity)
                                .alignLeading()
                            
                            Text(total.toGolfScore)
                                .font(.dmSans, size: 15, weight: .bold)
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
                        .font(.dmSans, size: 17, weight: .regular)
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
//                    Text("Edit")
//                        .font(.dmSans, size: 15, weight: .medium)
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
                        .font(.dmSans, size: 17, weight: .regular)
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
                        .font(.dmSans, size: 17, weight: .regular)
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
        let player = roundSession.players[p]
        let score = player.score(for: hole, handicaps: useHCP)
        //let label = score == .none ? "-" : "\(score.numericalValue)"

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
            icon(for: player, with: score)
//            Text(label)
//                .font(.dmSans, size: 15, weight: .bold)
//                .foregroundColor(score == .none ? colorScheme.lightGray : Color.systemBlack)
//                .frame(width: 40, height: 40)
//                .background(score == .none ? Color.clear : colorScheme.lightGray)
//                .border(score == .none ? colorScheme.lightGray : Color.clear, width: 3, cornerRadius: 6)
//                .cornerRadius(score.numericalValue < 0 ? 20 : 6)
        }
        .frame(width: 40, height: 40)
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
    
    @ViewBuilder private func icon(for player: Player, with score: PlayerScore) -> some View {
        let label = score == .none ? "-" : "\(score.numericalValue)"
        let color = Color.systemBlack//player.color.value
        let background = colorScheme.superlightGray
        
        if [.albatross, .eagle].contains(score) {
            
//            Text(label)
//                .font(.dmSans, size: 15, weight: .bold)
//                .foregroundColor(Color.systemBlack)
//                .frame(width: 32, height: 32)
//                .background(background)
//                .cornerRadius(20)
//                .border(color, width: 2, cornerRadius: 17)
//                .padding(4)
//                .border(color, width: 2, cornerRadius: 20)
            
            ZStack {
                Text(label)
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .frame(width: 40, height: 40)
                
                RoundedRectangle(cornerRadius: 14)
                    .stroke(colorScheme.lightGray, lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme.lightGray, lineWidth: 2)
                    .frame(width: 38, height: 38)
            }
            
        } else if score == .birdie {
            
//            Text(label)
//                .font(.dmSans, size: 15, weight: .bold)
//                .foregroundColor(Color.systemBlack)
//                .frame(width: 38, height: 38)
//                .background(background)
//                .cornerRadius(20)
//                .border(color, width: 2, cornerRadius: 20)
            
            ZStack {
                Text(label)
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .frame(width: 40, height: 40)
                
//                RoundedRectangle(cornerRadius: 2)
//                    .stroke(Color.systemGray3, lineWidth: 2)
//                    .frame(width: 30, height: 30)
                
                RoundedRectangle(cornerRadius: 20)
                    .stroke(colorScheme.lightGray, lineWidth: 2)
                    .frame(width: 38, height: 38)
            }
            
        } else if score == .par {
            
            Text(label)
                .font(.dmSans, size: 15, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .frame(width: 40, height: 40)
//                .background(background)
//                .cornerRadius(6)
            
        } else if score == .bogey {
            
//            Text(label)
//                .font(.dmSans, size: 15, weight: .bold)
//                .foregroundColor(Color.systemBlack)
//                .frame(width: 38, height: 38)
//                .background(background)
//                .cornerRadius(6)
//                .border(color, width: 2, cornerRadius: 6)
            
            ZStack {
                Text(label)
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .frame(width: 40, height: 40)
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colorScheme.lightGray, lineWidth: 2)
                    .frame(width: 38, height: 38)
            }
            
        } else if score == .none {
            
//            Text(label)
//                .font(.dmSans, size: 15, weight: .bold)
//                .foregroundColor(colorScheme.lightGray)
//                .frame(width: 40, height: 40)
//                .background(Color.clear)
//                .border(colorScheme.lightGray, width: 2, cornerRadius: 6)
            
            ZStack {
                Text(label)
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(colorScheme.lightGray)
                    .frame(width: 40, height: 40)
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(style: strokeStyle)
                    .foregroundStyle(colorScheme.lightGray)
                    //.stroke(colorScheme.lightGray, lineWidth: 2)
                    .frame(width: 38, height: 38)
            }
            
        } else {
            /// Double bogey or worse
//            Text(label)
//                .font(.dmSans, size: 15, weight: .bold)
//                .foregroundColor(Color.systemBlack)
//                .frame(width: 32, height: 32)
//                .background(background)
//                .cornerRadius(6)
//                .border(color, width: 2, cornerRadius: 2)
//                .padding(4)
//                .border(color, width: 2, cornerRadius: 6)
            ZStack {
                Text(label)
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .frame(width: 40, height: 40)
                
                RoundedRectangle(cornerRadius: 2)
                    .stroke(colorScheme.lightGray, lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colorScheme.lightGray, lineWidth: 2)
                    .frame(width: 38, height: 38)
            }
        }
    }
    
    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 0,
            dash: [1, 6],
            dashPhase: 0
        )
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
                //kyle.score = [1: "double"]//, 2: "bogey", 3: "par", 4: "birdie", 5: "eagle"]
                //kyle.handicap = [1: 1, 2: 1, 3: 1, 4: 0, 5: 2]
                roundSession.holeRange = Array(1...18)
                roundSession.players = [kyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
            }
            .holisticPreview()
    }
}
