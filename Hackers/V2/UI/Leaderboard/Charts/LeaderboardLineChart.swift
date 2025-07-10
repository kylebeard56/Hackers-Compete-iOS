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
    var exists: Bool
    
    init(
        id: UUID = UUID(),
        thru: Int = -1,
        hole: Int = -1,
        score: PlayerScore = .none,
        accured: Int = -1,
        exists: Bool = true
    ) {
        self.id = id
        self.thru = thru
        self.hole = hole
        self.score = score
        self.accured = accured
        self.exists = exists
    }
}

struct LeaderboardLineChart: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSessionV2
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var series = Series()
    @State private var segmentID: String = ""
    @State private var useHCP: Bool = true
    
    @State private var hoverHole: Int? = nil
    @State private var hoverHoleScore = HoleScore()
    @State private var originX: CGFloat = 0
    @State private var originY: CGFloat = 0
    
    /// Pad the y-axis ticks +/- this value to easier readibility
    private let kYAxisPadding: Int = 1
    
    private var seriesMin: Int {
        let m = series.scores.compactMap({ $0.accured }).min() ?? 0
        let l = Int(lowerBound)
        let u = Int(upperBound)
        
        /// Return global minimum between upper/lower projection (depending on above/below par) and the minimum cumulative score.
        return min(u <= l ? u : l, m) - kYAxisPadding
    }
    
    private var seriesMax: Int {
        let m = series.scores.compactMap({ $0.accured }).max() ?? 0
        let l = Int(lowerBound)
        let u = Int(upperBound)
        
        /// Return global maximum between upper/lower projection (depending on above/below par) and the maximum cumulative score.
        return max(u <= l ? l : u, m) + kYAxisPadding
    }
    
    private var xMin: Int {
        roundSession.holeRange.min() ?? 0
    }
    
    private var xMax: Int {
        roundSession.holeRange.max() ?? 0
    }
    
    /// Projection
    @State private var scores: [PlayerScore] = []
    @State private var mu: Double = 0.0
    @State private var sigma: Double = 0.0
    @State private var holesPlayed: Double = 0.0
    @State private var holesToForecast: Double = 0.0
    @State private var lowerProjectionValue: Double = 0.0
    @State private var upperProjectionValue: Double = 0.0
    @State private var lowerProjection: [(x: Double, y: Double)] = []
    @State private var upperProjection: [(x: Double, y: Double)] = []
    
    /// Rounded values for the lower/upper projection
    private var lowerBound: Double { lowerProjectionValue.rounded(.toNearestOrAwayFromZero) }
    private var upperBound: Double { upperProjectionValue.rounded(.toNearestOrAwayFromZero) }
    
    private var numericalScores: [Int] { scores.compactMap({ $0.numericalValue }) }
    private var scoresSum: Int { numericalScores.reduce(0, +) }
    
    private let kMinimumHolesScored: Int = 3
    
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
    
    /// User must score at least 3 holes to see chart
    private var showPopulatedState: Bool { roundSession.numberOfScoredHoles >= kMinimumHolesScored }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Scoring Projection")
                .font(.dmSans, size: 15, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            

            if showPopulatedState {
                populatedView
            } else {
                emptyView
            }
        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 12)
//        .background(Color.systemCard)
//        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
//        .cornerRadius(12)
        .onAppear() {
            if let p = roundSession.players.first {
                segmentID = p.id
                buildChartData(for: p)
                buildStatistics(for: p)
            }
        }
        .onChange(of: segmentID, perform: { id in
            /// Fire haptics when user taps to change (empty string means initial init)
            if segmentID != "" { Haptics.fire(.light) }
            if let p = roundSession.players.first(where: { $0.id == id }) {
                buildChartData(for: p)
                buildStatistics(for: p)
            }
        })
    }
    
    // MARK: - Empty State
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Picker("", selection: $segmentID) {
                ForEach(roundSession.players, id: \.self) { p in
                    Text(p.name)
                        .foregroundStyle(p.color.value)
                        .tag(p.id)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 20)
            
            emptyChart
                //.frame(height: 400)
            
            InfoBanner(
                text: "Chart will appear after Hole \(roundSession.holeRange[safe: kMinimumHolesScored - 1] ?? 0)",
                foregroundColor: Color.systemGray,
                backgroundColor: colorScheme.superlightGray
            )
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
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                AxisGridLine()
                AxisTick(centered: true)
                AxisValueLabel {
                    Text("\(value.index + 1)")
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: 2)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    Text(value.index.toGolfScore)
                }
            }
        }
    }
    
    // MARK: - Populated State
    
    private var populatedView: some View {
        VStack(spacing: 20) {
            Picker("", selection: $segmentID) {
                ForEach(roundSession.players, id: \.self) { p in
                    Text(p.name)
                        .foregroundStyle(p.color.value)
                        .tag(p.id)
                }
            }
            .pickerStyle(.segmented)
            
            if let player = roundSession.players.first(where: { $0.id == segmentID }), numericalScores.count < roundSession.numberOfHoles {
                Group {
                    Text("\(player.name) is \(scoresSum.toGolfScore) thru \(Int(holesPlayed)) with \(Int(holesToForecast - holesPlayed)) holes left to play. Based on scoring patterns, ")
                        .foregroundColor(Color.systemGray)
                    + Text("**we predict their final score will be between \(Int(lowerBound).toGolfScore) and \(Int(upperBound).toGolfScore)**.")
                        .foregroundColor(player.color.value)
                }
                .font(.dmSans, size: 13)
                .alignLeading()
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
            }
            
            populatedChart
                //.frame(height: 400)
            
            if roundSession.usingHandicaps {
                HandicapComputationToggle(useHCP: $useHCP)
            }
        }
    }
    
    private var populatedChart: some View {
        Chart {
            let color = series.player.color.value
            let interpolationMethod = InterpolationMethod.linear
            
            ForEach(series.scores.filter({ $0.exists }), id: \.id) { value in
                LineMark(
                    x: .value("Hole", value.thru),
                    y: .value("Score", value.accured),
                    series: .value("Recorded", "Recorded")
                )
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(color)
                
                if let hoverHole, hoverHole == value.thru {
                    RuleMark(x: .value("Index", value.thru))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .foregroundStyle(color)
                }
            }
            
            ForEach(lowerProjection, id: \.x) { point in
                LineMark(
                    x: .value("Hole", point.x),
                    y: .value("Score", point.y),
                    series: .value("Lower", "Lower")
                )
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 8]))
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(color)
            }
            
            ForEach(upperProjection, id: \.x) { point in
                LineMark(
                    x: .value("Hole", point.x),
                    y: .value("Score", point.y),
                    series: .value("Upper", "Upper")
                )
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 8]))
                .interpolationMethod(interpolationMethod)
                .foregroundStyle(color)
            }
            
            ForEach(series.scores.filter({ $0.exists }), id: \.id) { value in
                if hoverHole != nil, hoverHoleScore.thru == value.thru {
                    PointMark(
                        x: .value("Hole", value.thru),
                        y: .value("Score", value.accured)
                    )
                    .symbolSize(50)
                    .foregroundStyle(color)
                }
            }
            
            ForEach(series.scores.filter({ $0.exists }), id: \.thru) { value in
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
        .chartXScale(domain: [1, roundSession.numberOfHoles])
        .chartYScale(domain: [seriesMin, seriesMax])
        .chartXAxisLabel("Holes thru")
        .chartYAxisLabel("Cumulative score")
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .stride(by: 1)) { value in
                AxisGridLine()
                AxisTick(centered: true)
                AxisValueLabel {
                    Text("\(value.index + 1)")
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: seriesMax - seriesMin > 10 ? 2 : 1)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let tickValue = value.as(Int.self) {
                        Text(tickValue.toGolfScore)
                    }
                }
            }
        }
        .chartOverlay { chart in
            GeometryReader { geometry in
                chartOverlay(for: chart, with: geometry)
                
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragChanged(for: chart, with: geometry, using: value)
                            }
                            .onEnded { _ in hoverHole = nil }
                    )
            }
        }
    }
    
    // MARK: - Chart Components
    
    @ViewBuilder private func chartOverlay(for chart: ChartProxy, with geometry: GeometryProxy) -> some View {
        if hoverHole != nil, hoverHoleScore.exists {
            VStack {
                Text("Hole \(hoverHoleScore.hole)")
                    .font(.dmSans, size: 11, weight: .medium)
                    .foregroundStyle(Color.systemGray)
                Text(hoverHoleScore.score.shortName)
                    .font(.dmSans, size: 13, weight: .bold)
                    .foregroundStyle(Color.systemBlack)
                Text("\(hoverHoleScore.accured.toGolfScore) thru \(hoverHoleScore.thru)")
                    .font(.dmSans, size: 11, weight: .medium)
                    .foregroundStyle(Color.systemBlack)
            }
            .frame(width: 80, height: 60)
            .background(Blur(style: colorScheme.blurStyle).cornerRadius(8))
            .border(series.player.color.value, width: 2, cornerRadius: 8)
            .offset(
                x: geometry[chart.plotAreaFrame].width * 0.05,
                y: geometry[chart.plotAreaFrame].height * 0.1)
            .shadow(color: series.player.color.value.opacity(0.08), radius: 4, x: 0, y: 0)
        }
    }
    
    private func dragChanged(
        for chart: ChartProxy,
        with geometry: GeometryProxy,
        using value: DragGesture.Value
    ) {
        /// Convert the gesture location to the coordinate space of the plot area.
        let origin = geometry[chart.plotAreaFrame].origin
        let location = CGPoint(
            x: value.location.x - origin.x,
            y: value.location.y - origin.y
        )
        
        /// Get the x (hole) and y (score) value from the location.
        let (thru, _) = chart.value(at: location, as: (Int, Int).self) ?? (-1, -1)
        
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
    
    // MARK: - Chart Computation
    
    private func buildChartData(for player: Player) {
        var s = Series(player: player)
        var thru = 1
        for hole in roundSession.holeRange {
            let ps = player.score(for: hole)
            let hs = HoleScore(
                thru: thru,
                hole: hole,
                score: ps,
                accured: accrued(for: player, thru: hole),
                exists: ps != .none
            )
            s.scores.append(hs)
            thru += 1
        }
        
        series = s
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
    
    // MARK: - Statistical Projection
    
    private func buildStatistics(for p: Player) {
        if !showPopulatedState { return }
        
        scores = p.score.compactMap({ p.score(for: $0.key, handicaps: useHCP) }) .filter({ $0 != .none })
        
        /// 1. Compute the mean (mu) and standrd deviation (sigma)
        mu = mean(scores: numericalScores)
        sigma = standardDeviation(scores: numericalScores, mean: mu)
        
        /// 2. Set number of holes played and number of holes total
        holesPlayed = Double(numericalScores.count)
        holesToForecast = Double(roundSession.numberOfHoles)
        
        /// 3. Compute t-value that will be used to calculate margin of error
        let tValue = tCriticalValue(for: Int(holesPlayed) - 1)
        let marginOfError = tValue * (sigma / sqrt(holesPlayed))
        let marginBias: Double = pow(1 + abs(mu), 0.69) // Bias the MOE window by (1 + mu)^0.69
        
        /// 4. Estimate the upper and lower forecasted values raw
        lowerProjectionValue = mu * holesToForecast - marginOfError * marginBias
        upperProjectionValue = mu * holesToForecast + marginOfError * marginBias

        /// 5. Clear any old projection data and if all holes are scored, hide projection
        lowerProjection.removeAll()
        upperProjection.removeAll()
        if numericalScores.count == roundSession.numberOfHoles { return }
        
        /// 6. Compute linear forecast data from last scored hole to the estimated upper/lower projection
        if let prev = series.scores.filter({ $0.exists }).last {
            let holeCount = Double(roundSession.numberOfHoles)
            
            /// 6a. Starting point
            let start = (x: Double(prev.thru), y: Double(prev.accured))
            lowerProjection.append(start)
            upperProjection.append(start)
            
            /// 6b. Finishing point
            lowerProjection.append((x: holeCount, y: lowerBound))
            upperProjection.append((x: holeCount, y: upperBound))
        }
    }
    
    func mean(scores: [Int]) -> Double {
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    func standardDeviation(scores: [Int], mean: Double) -> Double {
        let variance = scores.reduce(0) { $0 + pow(Double($1) - mean, 2) } / Double(scores.count)
        return sqrt(variance)
    }
    
//    func normalDistribution(x: Double, mean: Double, standardDeviation: Double) -> Double {
//        let exponent = -pow(x - mean, 2) / (2 * pow(standardDeviation, 2))
//        return (1 / (standardDeviation * sqrt(2 * Double.pi))) * exp(exponent)
//    }
    
    func tCriticalValue(for dof: Int) -> Double {
        let tValues: [Int: Double] = [
            1: 12.706,
            2: 4.303,
            3: 3.182,
            4: 2.776,
            5: 2.571,
            6: 2.447,
            7: 2.365,
            8: 2.306,
            9: 2.262,
            10: 2.228,
            11: 2.201,
            12: 2.179,
            13: 2.160,
            14: 2.145,
            15: 2.131,
            16: 2.120,
            17: 2.110,
            18: 2.101,
            19: 2.093,
            20: 2.086,
            21: 2.080,
            22: 2.074,
            23: 2.069,
            24: 2.064,
            25: 2.060,
            26: 2.056,
            27: 2.052,
            28: 2.048,
            29: 2.045,
            30: 2.042
        ]
        return tValues[dof] ?? 1.96
    }
    
//    func normalCDF(z: Double) -> Double {
//        return 0.5 * (1.0 + Darwin.erf(z / sqrt(2.0)))
//    }
//        
//    func probability(for score: PlayerScore, using mu: Double, _ sigma: Double) -> Double {
//        switch score {
//        case .albatross:    return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -3.49, x2: -2.5)
//        case .eagle:        return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -2.49, x2: -1.5)
//        case .birdie:       return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -1.49, x2: -0.5)
//        case .par:          return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -0.49, x2: 0.49)
//        case .bogey:        return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 0.5, x2: 1.49)
//        case .double:       return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 1.5, x2: 2.49)
//        case .triple:       return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 2.5, x2: 3.49)
//        case .quad:         return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 3.5, x2: 4.49)
//        case .quin:         return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 4.5, x2: 5.49)
//        case .sex:          return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 5.5, x2: 6.49)
//        case .none:         return 0.0
//        }
//    }
//    
//    func areaUnderNormalCurve(mu: Double, sigma: Double, x1: Double, x2: Double) -> Double {
//        let z1 = (x1 - mu) / sigma
//        let z2 = (x2 - mu) / sigma
//        let area = normalCDF(z: z2) - normalCDF(z: z1)
//        return area
//    }
//    
//    func targetProbability(for total: Int) -> Double {
//        print(#function)
//        let holesRemaining = holesToForecast - holesPlayed
//        let currentTotal = scores.compactMap({ $0.numericalValue }).reduce(0, +)
//        let meanTotal = mu * holesRemaining
//        let scoreMargin = Double(total - currentTotal)
//        let z = (scoreMargin - meanTotal) / sigma * sqrt(holesRemaining)
//        let p = normalCDF(z: z) * 100
//        
//        return p
//    }
}

struct LeaderboardLineChart_Previews: PreviewProvider {
    static var app = AppSessionV2()
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
            round.numberOfHoles = 9
            var kyle = kPlayerKyle
            //kyle.score = [8: "bogey", 9: "par", 1: "triple", 2: "bogey", 3: "par", 4: "birdie", 5: "birdie", 6: "bogey", 7: "double"]
            
            var sarah = kPlayerSarah
            //sarah.score = [8: "double", 9: "double", 1: "birdie", 2: "eagle", 3: "birdie", 4: "birdie", 5: "par", 6: "par", 7: "bogey"]
            
            var murphy = kPlayerMurphy
            //murphy.score = [1: "par", 2: "bogey", 3: "bogey", 4: "double", 5: "par", 6: "bogey", 7: "double", 8: "birdie", 9: "par"]
            
            var pablo = kPlayerPablo
            //pablo.score = [1: "bogey", 2: "par", 3: "bogey", 4: "eagle", 5: "eagle", 6: "bogey", 7: "bogey", 8: "bogey", 9: "double"]
            
            round.players = [kyle, sarah, murphy, pablo]
        }
    }
}
