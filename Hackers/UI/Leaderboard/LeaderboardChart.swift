//
//  LeaderboardChart.swift
//  Hackers
//
//  Created by Kyle Beard on 6/13/24.
//

import Charts
import SwiftUI
import UIKit

fileprivate struct Series: Hashable, Identifiable {
    var id: String { player.id }
    var player: Player
    var scores: [HoleScore]
    
    init(player: Player = Player(), scores: [HoleScore] = []) {
        self.player = player
        self.scores = scores
    }
}

fileprivate struct HoleScore: Hashable, Identifiable {
    var id = UUID()
    var thru: Int
    var hole: Int
    var score: PlayerScore
    var accured: Int
    
    init(id: UUID = UUID(), thru: Int = -1, hole: Int = -1, score: PlayerScore = .none, accured: Int = -1) {
        self.id = id
        self.thru = thru
        self.hole = hole
        self.score = score
        self.accured = accured
    }
}

struct LeaderboardLineChart: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession

    @State private var series = Series()
    @State private var segmentID: String = ""
    
    @State private var hoverHole: Int? = nil
    @State private var hoverHoleScore = HoleScore()
    @State private var originX: CGFloat = 0
    @State private var originY: CGFloat = 0
    
    @State private var useHCP: Bool = true
    
    private var seriesMin: Int {
        series.scores.compactMap({ $0.accured }).min() ?? 0
    }
    
    private var seriesMax: Int {
        series.scores.compactMap({ $0.accured }).max() ?? 0
    }
    
    private var emptySeries = Series(
        player: Player(),
        scores: [
            HoleScore(thru: 1, hole: 1, score: .par, accured: 0),
            HoleScore(thru: 2, hole: 2, score: .bogey, accured: 1),
            HoleScore(thru: 3, hole: 3, score: .par, accured: 1),
            HoleScore(thru: 4, hole: 4, score: .double, accured: 3),
            HoleScore(thru: 5, hole: 5, score: .par, accured: 3),
            HoleScore(thru: 6, hole: 6, score: .birdie, accured: 2),
            HoleScore(thru: 7, hole: 7, score: .double, accured: 4),
            HoleScore(thru: 8, hole: 8, score: .bogey, accured: 5),
            HoleScore(thru: 9, hole: 9, score: .par, accured: 5),
        ]
    )
    
    var body: some View {
        VStack {
            if roundSession.numberOfScoredHoles < 3 {
                emptyView
            } else {
                populatedView
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
        .onAppear() {
            if let p = roundSession.players.first {
                segmentID = p.id
                buildChartData(for: p)
            }
        }
        .onChange(of: segmentID, perform: { id in
            /// Fire haptics when user taps to change (empty string means initial init)
            if segmentID != "" { Haptics.fire(.light) }
            if let p = roundSession.players.first(where: { $0.id == id }) {
                buildChartData(for: p)
            }
        })
    }
    
    // MARK: - Empty State
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Text("Play 3 holes to see unlock this chart")
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundStyle(Color.systemGray)
                .alignLeading()
            
            emptyChart
        }
    }
    
    private var emptyChart: some View {
        Chart {
            let color = colorScheme.lightGray
            let interpolationMethod = InterpolationMethod.linear
            
            ForEach(emptySeries.scores, id: \.id) { value in
                LineMark(
                    x: .value("Hole", value.thru),
                    y: .value("Score", value.accured)
                )
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(color)
            }
            
            ForEach(emptySeries.scores, id: \.thru) { value in
                AreaMark(
                    x: .value("Hole", value.thru),
                    y: .value("Score", value.accured)
                )
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXScale(domain: [1, 9])
        .chartYScale(domain: [0, 5])
    }
    
    // MARK: - Populated State
    
    private var populatedView: some View {
        VStack {
            Picker("", selection: $segmentID) {
                ForEach(roundSession.players, id: \.self) { p in
                    Text(p.name)
                        .foregroundStyle(p.color.value)
                        .tag(p.id)
                }
            }
            .pickerStyle(.segmented)
            
            populatedChart
            
            // TODO: RELEASE
            /// append `deviceSettings.showLeaderboardLineChartTip` to the conditional logic below:
            if let player = roundSession.players.first(where: { $0.id == segmentID }) {
                InfoBanner(
                    icon: "e1a2",
                    text: "Tap and drag to see hole-by-hole score",
                    foregroundColor: Color.systemGray,
                    backgroundColor: colorScheme.superlightGray
                )
            }
            
            if roundSession.usingHandicaps {
                HandicapComputationToggle(useHCP: $useHCP)
            }
        }
    }
    
    private var populatedChart: some View {
        Chart {
            let color = series.player.color.value
            let interpolationMethod = InterpolationMethod.linear
            
            ForEach(series.scores, id: \.id) { value in
                LineMark(
                    x: .value("Hole", value.thru),
                    y: .value("Score", value.accured)
                )
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(color)
                
                if let hoverHole, hoverHole == value.thru {
                    RectangleMark(x: .value("Index", value.thru), width: 1)
                        .foregroundStyle(Color.systemGray3)
                }
            }
            
            ForEach(series.scores, id: \.thru) { value in
                AreaMark(
                    x: .value("Hole", value.thru),
                    y: .value("Score", value.accured)
                )
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXScale(domain: [roundSession.holeRange.min() ?? 0, roundSession.holeRange.max() ?? 0])
        .chartYScale(domain: [seriesMin - 2, seriesMax + 2])
        .chartXAxisLabel("Holes thru")
        .chartYAxisLabel("Score over par")
        .chartOverlay { chart in
            GeometryReader { geometry in
                if hoverHole != nil {
                    VStack {
                        Text("Hole \(hoverHoleScore.hole)")
                            .font(.dmSans(size: 11, weight: .medium))
                            .foregroundStyle(Color.systemGray)
                        Text(hoverHoleScore.score.shortName)
                            .font(.dmSans(size: 13, weight: .bold))
                            .foregroundStyle(Color.systemBlack)
                        Text("\(hoverHoleScore.accured.toGolfScore) \(hoverHoleScore.accured > 0 ? "over" : "under")")
                            .font(.dmSans(size: 11, weight: .medium))
                            .foregroundStyle(Color.systemBlack)
                    }
                    .frame(width: 80, height: 60)
                    .background(Blur(style: colorScheme.blurStyle).cornerRadius(8))
                    .border(series.player.color.value, width: 2, cornerRadius: 8)
                    .offset(x: 0, y: geometry[chart.plotAreaFrame].height * 0.1)
                    .shadow(color: series.player.color.value.opacity(0.08), radius: 4, x: 0, y: 0)
                }
                
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                /// Convert the gesture location to the coordinate space of the plot area.
                                let origin = geometry[chart.plotAreaFrame].origin
                                let location = CGPoint(
                                    x: value.location.x - origin.x,
                                    y: value.location.y - origin.y
                                )
                                
                                /// Get the x (hole) and y (score) value from the location.
                                let (thru, score) = chart.value(at: location, as: (Int, Int).self) ?? (-1, -1)
                                
                                /// If `thru` changed, capture instance immediately to know touch location.
                                if thru != hoverHole {
                                    Haptics.fire(.light)
                                    originX = location.x
                                    originY = location.y
                                }
                                hoverHole = thru
                                
                                /// Get the full score value at the specific index to save for the touch-enabled infographic.
                                if let i = series.scores.firstIndex(where: { $0.thru == thru }) {
                                    hoverHoleScore = series.scores[i]
                                }
                            }
                            .onEnded { _ in
                                // TODO: RELEASE
                                /// deviceSettings.showLeaderboardLineChartTip = false
                                hoverHole = nil
                            }
                    )
            }
        }
    }
    
    private func buildChartData(for player: Player) {
        var s = Series(player: player)
        var thru = 1
        print("")
        for hole in roundSession.holeRange {
            s.scores.append(
                HoleScore(
                    thru: thru,
                    hole: hole,
                    score: player.score(for: hole),
                    accured: accrued(for: player, thru: hole)
                )
            )
            thru += 1
        }
        
        series = s
        printPretty(s)
    }
    
    private func accrued(for player: Player, thru hole: Int) -> Int {
        let left = roundSession.holeRange.firstIndex(of: roundSession.startingHole) ?? 0
        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
        let range = roundSession.holeRange[left...right]
        let score = ScoreUtil.Stroke.computeTotal(
            for: player,
            over: Array(range),
            using: .medal,
            handicaps: useHCP
        )
        return score
    }
}

struct LeaderboardLineChart_Previews: PreviewProvider {
    static var app = AppSession()
    static var purchase = PurchaseStore()
    static var round = RoundSession()
    
    static var previews: some View {
        VStack {
            Spacer(minLength: 0)
            
            LeaderboardLineChart()
                .frame(height: 400)
                .padding(20)
            
            Spacer(minLength: 0)
        }
        .background(Color.systemBackground)
        .environmentObject(app)
        .environmentObject(purchase)
        .environmentObject(round)
        .holisticPreview()
        .onAppear() {
            round.holeRange = [8,9,1,2,3,4,5,6,7]
            round.startingHole = 8
            var kyle = kPlayerKyle
            kyle.score = [1: "triple", 2: "birdie"]//, 3: "par", 4: "triple", 5: "eagle", 6: "bogey", 7: "bogey", 8: "double", 9: "par"]
            
            var sarah = kPlayerSarah
            sarah.score = [1: "birdie", 2: "par"]//, 3: "triple", 4: "eagle", 5: "birdie", 6: "par", 7: "bogey", 8: "double", 9: "double"]
            
            var murphy = kPlayerMurphy
            murphy.score = [1: "par", 2: "bogey"]//, 3: "bogey", 4: "double", 5: "par", 6: "bogey", 7: "double", 8: "birdie", 9: "par"]
            
            var pablo = kPlayerPablo
            pablo.score = [1: "bogey", 2: "par"]//, 3: "bogey", 4: "eagle", 5: "eagle", 6: "bogey", 7: "bogey", 8: "bogey", 9: "double"]
            
            round.players = [kyle, sarah, murphy, pablo]
        }
    }
}
