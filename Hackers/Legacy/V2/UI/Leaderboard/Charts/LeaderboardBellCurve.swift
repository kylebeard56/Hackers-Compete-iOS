//
//  LeaderboardBellCurve.swift
//  Hackers
//
//  Created by Kyle Beard on 6/17/24.
//

import Accelerate
import Charts
import SwiftUI


struct ScoreProbability: Identifiable {
    var id = UUID()
    var score: Int
    var probability: Double
    
    init(id: UUID = UUID(), score: Int = 0, probability: Double = 0.0) {
        self.id = id
        self.score = score
        self.probability = probability
    }
}

struct LeaderboardBellCurve: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSessionV2
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var player: Player = Player()
    @State private var segmentID: String = ""
    
    @State private var hoverScore: PlayerScore? = nil
    @State private var originX: CGFloat = 0
    @State private var originY: CGFloat = 0

    @State private var scores: [PlayerScore] = []
    @State private var mu: Double = 0.0
    @State private var sigma: Double = 0.0
    @State private var xValues: [Double] = []
    @State private var yValues: [Double] = []
    @State private var data: [(x: Double, y: Double)] = []
    @State private var holesPlayed: Double = 0.0
    @State private var tValue: Double = 0.0
    @State private var marginOfError: Double = 0.0
    @State private var holesToForecast: Double = 0.0
    @State private var lowerEstimateForecast: Double = 0.0
    @State private var upperEstimateForecast: Double = 0.0
    @State private var lowerRange: Double = 0.0
    @State private var upperRange: Double = 0.0
    
    @State private var targetScore: Double = 0.0
    
    private var numericalScores: [Int] {
        scores.compactMap({ $0.numericalValue })
    }
    
    private var scoresSum: Int {
        numericalScores.reduce(0, +)
    }
    
    let placeholderScores: [PlayerScore] = [.triple, .birdie, .par, .triple, .eagle, .bogey]
    private var notEnoughHolesPlayed: Bool {
        scores.count < 3
    }
    
    private var notEnoughVariance: Bool {
        scores.uniques.count <= 1
    }
    
    @State private var scoreProbabilities: [(x: Double, y: Double)] = []
    
    private var minProb: Int {
        scoreProbabilities.map({ Int($0.x) }).min() ?? 0
    }
    
    private var maxProb: Int {
        scoreProbabilities.map({ Int($0.x) }).max() ?? 0
    }
    
    private var roundCompletion: Double {
        let scoredHoles = player.score.compactMap({ PlayerScore(rawValue: $0.value) }).filter({ $0 != .none }).count
        return Double(scoredHoles / roundSession.numberOfHoles)
    }
    
    private let minimumCompletionRatio: Double = 0.333
    
    private var appearanceHole: Int {
        thresholdIndex(array: roundSession.holeRange, percentage: minimumCompletionRatio)
    }
    
    func thresholdIndex(array: [Int], percentage: Double) -> Int {
        let N = array.count
        let index = ceil(Double(N) * (1 - percentage))
        return Int(index)
    }
    
    var body: some View {
        VStack {
            Text("Round Prediction")
                .font(.dmSans, size: 15, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            probabilityView
            
//            if notEnoughHolesPlayed {
//                insufficientDataView
//            } else if notEnoughVariance {
//                insufficientVarianceView
//            } else {
//                populatedView
//            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
        .onAppear() {
            if let p = roundSession.players.first {
                segmentID = p.id
                DispatchQueue.main.async(qos: .background, execute: {
                    self.buildStatistics(for: p)
                })
            }
        }
        .onChange(of: segmentID, perform: { id in
            /// Fire haptics when user taps to change (empty string means initial init)
            if segmentID != "" { Haptics.fire(.light) }
            if let p = roundSession.players.first(where: { $0.id == id }) {
//                withAnimation(.easeOut(duration: 0.2)) {
                    player = p
                DispatchQueue.main.async(qos: .background, execute: {
                    self.buildStatistics(for: p)
                })
//                }
            }
        })
    }
    
    // MARK: - Insufficient data view
    
//    private var insufficientDataView: some View {
//        VStack(spacing: 20) {
//            Picker("", selection: $segmentID) {
//                ForEach(roundSession.players, id: \.self) { p in
//                    Text(p.name)
//                        .foregroundStyle(p.color.value)
//                        .tag(p.id)
//                }
//            }
//            .pickerStyle(.segmented)
//            .padding(.bottom, 20)
//            
//            emptyChart
//            
//            VStack(spacing: 4) {
//                Text("Not enough data")
//                    .font(.dmSans, size: 12, weight: .bold)
//                    .foregroundStyle(Color.systemBlack)
//                    .alignLeading()
//                
//                Text("Play at least (3) holes to view this chart.")
//                    .font(.dmSans, size: 12, weight: .regular)
//                    .foregroundStyle(Color.systemGray)
//                    .alignLeading()
//            }
//        }
//    }
    
    // MARK: - Insufficient variance view
    
//    private var insufficientVarianceView: some View {
//        VStack(spacing: 20) {
//            Picker("", selection: $segmentID) {
//                ForEach(roundSession.players, id: \.self) { p in
//                    Text(p.name)
//                        .foregroundStyle(p.color.value)
//                        .tag(p.id)
//                }
//            }
//            .pickerStyle(.segmented)
//            .padding(.bottom, 20)
//            
//            emptyChart
//            
//            VStack(spacing: 4) {
//                Text("Not enough variety")
//                    .font(.dmSans, size: 12, weight: .bold)
//                    .foregroundStyle(Color.systemBlack)
//                    .alignLeading()
//                
//                Text("Input (2) different scores to view this chart.")
//                    .font(.dmSans, size: 12, weight: .regular)
//                    .foregroundStyle(Color.systemGray)
//                    .alignLeading()
//            }
//        }
//    }
    
//    private var emptyChart: some View {
//        Chart {
//            let color = colorScheme.lightGray
//            
//            ForEach(data, id: \.x) { point in
//                LineMark(
//                    x: .value("Score", point.x),
//                    y: .value("Probability Density", point.y)
//                )
//                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
//                .foregroundStyle(color)
//            }
//            
//            ForEach(data, id: \.x) { point in
//                AreaMark(
//                    x: .value("Score", point.x),
//                    y: .value("Probability Density", point.y)
//                )
//                .foregroundStyle(
//                    LinearGradient(
//                        colors: [color.opacity(0.4), Color.clear],
//                        startPoint: .top,
//                        endPoint: .bottom
//                    )
//                )
//            }
//        }
//        .frame(height: 300)
//        .chartXScale(domain: [mu - 3.25 * sigma, mu + 3.25 * sigma])
//        .chartYScale(domain: [0, 1 / (sigma * sqrt(2 * .pi)) + 0.05])
//    }
    
    // MARK: - Populated view
    
//    private var populatedView: some View {
//        VStack(spacing: 20) {
//            Picker("", selection: $segmentID) {
//                ForEach(roundSession.players, id: \.self) { p in
//                    Text(p.name)
//                        .foregroundStyle(p.color.value)
//                        .tag(p.id)
//                }
//            }
//            .pickerStyle(.segmented)
//            
//            analysisText
//            
//            probabilityChart
//            
//            populatedChart
//            
//            // TODO: RELEASE
//            /// append `deviceSettings.showLeaderboardBellCurvetTip` to the conditional logic below:
//            InfoBanner(
//                icon: "e1a2",
//                text: "Drag along curve to see probability",
//                foregroundColor: Color.systemGray,
//                backgroundColor: colorScheme.superlightGray
//            )
//        }
//    }
//    
//    private var populatedChart: some View {
//        Chart {
//            ForEach(data, id: \.x) { point in
//                LineMark(
//                    x: .value("Score", point.x),
//                    y: .value("Probability Density", point.y)
//                )
//                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
//                .foregroundStyle(player.color.value)
//
//                if let s = hoverScore, s.numericalValue == Int(point.x) {
//                    RuleMark(x: .value("Score", s.numericalValue))
//                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
//                        .foregroundStyle(player.color.value)
//                }
//            }
//            
//            ForEach(PlayerScore.allCases, id: \.self) { score in
//                let value = score.numericalValue
//                if score == hoverScore {
//                    PointMark(
//                        x: .value("Score", value),
//                        y: .value("Probability Density", normalDistribution(x: Double(value), mean: mu, standardDeviation: sigma))
//                    )
//                    .symbolSize(50)
//                    .foregroundStyle(player.color.value)
//                }
//            }
//            
//            ForEach(data, id: \.x) { point in
//                AreaMark(
//                    x: .value("Score", point.x),
//                    y: .value("Probability Density", point.y)
//                )
//                .foregroundStyle(
//                    LinearGradient(
//                        colors: [player.color.value.opacity(0.4), Color.clear],
//                        startPoint: .top,
//                        endPoint: .bottom
//                    )
//                )
//            }
//            
//            RuleMark(x: .value("Mean", mu))
//                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
//                .foregroundStyle(Color.systemBlack)
//                .annotation(position: .top, alignment: .center) {
////                    Text("\(mu, specifier: "%0.1f") average above par")
//                    Text("AVG")
//                        .font(.dmSans, size: 11, weight: .bold)
//                        .foregroundColor(Color.systemBlack)
//                }
//        }
//        .frame(height: 300)
//        .chartXScale(domain: [mu - 3.25 * sigma, mu + 3.25 * sigma])
//        .chartYScale(domain: [0, 1 / (sigma * sqrt(2 * .pi)) + 0.05])
//        .chartXAxis {
//            AxisMarks(values: .stride(by: 2)) { value in
//                AxisGridLine()
//                AxisTick(centered: true)
//                AxisValueLabel {
//                    Text((value.index - 2).toPlayerScore.shortName)
//                }
//            }
//        }
//        .chartYAxis {
//            AxisMarks(values: .stride(by: 2)) { value in
//                AxisGridLine()
//                AxisTick()
////                AxisValueLabel {
////                    Text(value.index)
////                }
//            }
//        }
//        .chartOverlay { chart in
//            GeometryReader { geometry in
//                if let score = hoverScore {
//                    VStack {
//                        Text("\(score.shortName)")
//                            .font(.dmSans, size: 11, weight: .medium)
//                            .foregroundStyle(Color.systemGray)
//                        Text("\(probability(for: score, using: mu, sigma) * 100, specifier: "%0.1f")%")
//                            .font(.dmSans, size: 13, weight: .bold)
//                            .foregroundStyle(Color.systemBlack)
//                        Text("Chance")
//                            .font(.dmSans, size: 11, weight: .medium)
//                            .foregroundStyle(Color.systemBlack)
//                    }
//                    .frame(width: 80, height: 60)
//                    .background(Blur(style: colorScheme.blurStyle).cornerRadius(8))
//                    .border(player.color.value, width: 2, cornerRadius: 8)
//                    .offset(
//                        x: geometry[chart.plotAreaFrame].width * 0.05,
//                        y: geometry[chart.plotAreaFrame].height * 0.05
//                    )
//                    .shadow(color: player.color.value.opacity(0.08), radius: 4, x: 0, y: 0)
//                }
//                
//                Rectangle()
//                    .fill(Color.clear)
//                    .contentShape(Rectangle())
//                    .gesture(
//                        DragGesture()
//                            .onChanged { value in
//                                /// Convert the gesture location to the coordinate space of the plot area.
//                                let origin = geometry[chart.plotAreaFrame].origin
//                                let location = CGPoint(
//                                    x: value.location.x - origin.x,
//                                    y: value.location.y - origin.y
//                                )
//                                
//                                /// Get the x (score) and y (density) value from the location.
//                                let (score, _) = chart.value(at: location, as: (Int, Int).self) ?? (-1, -1)
//                                
//                                /// If `thru` changed, capture instance immediately to know touch location.
//                                if score.toPlayerScore != hoverScore {
//                                    Haptics.fire(.light)
//                                    originX = location.x
//                                    originY = location.y
//                                }
//                                hoverScore = score.toPlayerScore
//                            }
//                            .onEnded { _ in
//                                // TODO: RELEASE
//                                /// deviceSettings.showLeaderboardBellCurveTip = false
//                                hoverScore = nil
//                            }
//                    )
//            }
//        }
//    }
    
    // MARK: - Probability view
    
    @ViewBuilder private var probabilityView: some View {
        VStack(spacing: 20) {
            Picker("", selection: $segmentID) {
                ForEach(roundSession.players, id: \.self) { p in
                    Text(p.name)
                        .foregroundStyle(p.color.value)
                        .tag(p.id)
                }
            }
            .pickerStyle(.segmented)
            
//            if roundCompletion < 0.5 {
//                placeholderProbabilityChart
//                
//                InfoBanner(
//                    text: "Projections will appear on Hole \(appearanceHole)",
//                    foregroundColor: Color.systemGray,
//                    backgroundColor: colorScheme.superlightGray
//                )
//            } else {
//                analysisText
//                probabilityChart
//            }
            if roundCompletion == 1.0 {
                InfoBanner(
                    icon: "f450",
                    text: "This round is fully scored",
                    foregroundColor: Color.systemGray,
                    backgroundColor: colorScheme.superlightGray
                )
            } else if roundCompletion < 0.5 {
                placeholderProbabilityChart
                
                InfoBanner(
                    text: "Projections will appear on Hole \(appearanceHole)",
                    foregroundColor: Color.systemGray,
                    backgroundColor: colorScheme.superlightGray
                )
            } else {
                analysisText
                probabilityChart
            }
        }
    }
    
    private let placeholderProbabilities: [(x: Double, y: Double)] = [
        //(x: 2.0, y: 0.011928172701436424),
        (x: 3.0, y: 0.29285495426421004),
        (x: 4.0, y: 3.309628986109675),
        (x: 5.0, y: 17.91632333744402),
        (x: 6.0, y: 50.0),
        (x: 7.0, y: 82.08367666255599),
        (x: 8.0, y: 96.69037101389033),
        (x: 9.0, y: 99.70714504573579)
    ]
    
    private var placeholderProbabilityChart: some View {
        Chart {
            let color = colorScheme.lightGray
            let method: InterpolationMethod = .cardinal
            
            ForEach(placeholderProbabilities, id: \.x) { point in
                LineMark(
                    x: .value("Hole", point.x),
                    y: .value("Probability", point.y)
                )
                .interpolationMethod(method)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(color)
            }
            
            ForEach(placeholderProbabilities, id: \.x) { point in
                AreaMark(
                    x: .value("Hole", point.x),
                    y: .value("Probability", point.y)
                )
                .interpolationMethod(method)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            RuleMark(x: .value("Mean", 5))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
                .foregroundStyle(Color.systemGray3)
            
            RuleMark(x: .value("Mean", 7))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
                .foregroundStyle(Color.systemGray3)
        }
        .frame(height: 300)
        .chartXScale(domain: [3, 9])
        .chartYScale(domain: [0, 100])
//        .chartXAxisLabel("Projected final score")
//        .chartYAxisLabel("Probability")
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                AxisGridLine()
                AxisTick(centered: true)
                AxisValueLabel {
                    Text((value.index + 2).toGolfScore)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: 20)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    Text("\(value.index * 20)%")
                }
            }
        }
    }
    
    private var probabilityChart: some View {
        Chart {
            
            let method: InterpolationMethod = .cardinal
            
            ForEach(scoreProbabilities, id: \.x) { point in
                LineMark(
                    x: .value("Hole", point.x),
                    y: .value("Probability", point.y)
                )
                .interpolationMethod(method)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(player.color.value)

                if let s = hoverScore, s.numericalValue == Int(point.x) {
                    RuleMark(x: .value("Score", s.numericalValue))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .foregroundStyle(player.color.value)
                }
            }
            
            ForEach(scoreProbabilities, id: \.x) { point in
                AreaMark(
                    x: .value("Hole", point.x),
                    y: .value("Probability", point.y)
                )
                .interpolationMethod(method)
                .foregroundStyle(
                    LinearGradient(
                        colors: [player.color.value.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            RuleMark(x: .value("Mean", Int(lowerRange.rounded(.toNearestOrEven))))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
                .foregroundStyle(player.color.value)
            
            RuleMark(x: .value("Mean", Int(upperRange.rounded(.toNearestOrEven))))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 4]))
                .foregroundStyle(player.color.value)
        }
        .frame(height: 300)
        .chartXScale(domain: [minProb, maxProb])
        .chartYScale(domain: [0, 100])
        .chartXAxisLabel("Projected final score")
        .chartYAxisLabel("Probability")
        .chartXAxis {
            AxisMarks(values: .stride(by: 1)) { value in
                AxisGridLine()
                AxisTick(centered: true)
                AxisValueLabel {
                    Text((value.index + minProb).toGolfScore)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: 20)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    Text("\(value.index * 20)%")
                }
            }
        }
    }
    
    private var analysisText: some View {
        VStack(spacing: 4) {
//            Text("Predicting your round")
//                .font(.dmSans, size: 13, weight: .bold)
//                .foregroundStyle(Color.systemBlack)
//                .alignLeading()
            
//            Group {
//                Text("This bell curve represents the distribution of scores through your round. You're currently averaging ")
//                    .foregroundColor(Color.systemGray)
//                + Text("**\(mu, specifier: "%.1f") strokes \(mu > 0 ? "above" : "below") par each hole**")
//                    .foregroundColor(player.color.value)
//                + Text(" over the past \(Int(holesPlayed)) holes.")
//                    .foregroundColor(Color.systemGray)
//            }
//            .font(.dmSans, size: 12)
//            .alignLeading()
//            .multilineTextAlignment(.leading)
            
            Group {
                Text("Using Hackers magic, we know you are \(scoresSum.toGolfScore) thru \(Int(holesPlayed)) with \(Int(holesToForecast - holesPlayed)) holes left to play. Based on your scoring patterns, ")
                    .foregroundColor(Color.systemGray)
                + Text("**we predict your final score will be \(Int(lowerRange.rounded(.toNearestOrEven)).toGolfScore) to \(Int(upperRange.rounded(.toNearestOrEven)).toGolfScore)**.")
                    .foregroundColor(player.color.value)
            }
            .font(.dmSans, size: 13)
            .alignLeading()
            .multilineTextAlignment(.leading)
            
//            Text("*The margin of error for your predicted score is ±\(marginOfError, specifier: "%.2f") strokes and will become more accurate as your round continues.*")
//            .font(.dmSans, size: 12)
//            .foregroundStyle(Color.systemGray)
//            .alignLeading()
//            .multilineTextAlignment(.leading)
            
//            HStack {
//                Text("Target score probability")
//                    .font(.dmSans, size: 12, weight: .bold)
//                    .foregroundStyle(Color.systemBlack)
//                
//                Spacer(minLength: 0)
//                
//                Text(Int(targetScore).toGolfScore)
//                    .font(.dmSans, size: 12, weight: .bold)
//                    .foregroundStyle(player.color.value)
//            }
//            
//            Slider(value: $targetScore, in: -18...36, step: 1.0)
//            
//            Text("You have a target score of \(Int(targetScore).toGolfScore) and are currently \(scoresSum.toGolfScore) with \(Int(holesToForecast - holesPlayed)) holes to play, which we give a \(targetProbability(for: Int(targetScore)), specifier: "%.2f")% chance of happening.")
//            .font(.dmSans, size: 12)
//            .foregroundStyle(Color.systemGray)
//            .alignLeading()
//            .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - Statistics functions
    
    private func buildStatistics(for p: Player) {
        print("\(#function) START")
        
        if roundCompletion < 0.5 { return }
        
        // TODO: Include hcp here
        scores = p.score.compactMap({ PlayerScore(rawValue: $0.value) }).filter({ $0 != .none })
        
        if scores.isEmpty { return }
        
        mu = mean(scores: numericalScores)
        sigma = standardDeviation(scores: numericalScores, mean: mu)
        //xValues = stride(from: mu - 3 * sigma, through: mu + 3 * sigma, by: 0.1).map { $0 }
        //yValues = xValues.map { normalDistribution(x: $0, mean: mu, standardDeviation: sigma) }
        
//        let sigmaSquared = pow(sigma, 2)
//        let sqrtTwoPi = sqrt(2 * Double.pi)
//         
//        yValues = xValues.map { x in
//            let exponent = -pow(x - mu, 2) / (2 * sigmaSquared)
//            return (1 / (sigma * sqrtTwoPi)) * exp(exponent)
//        }
//        
//        data = Array(zip(xValues, yValues)).map { (x, y) in
//            (x: x, y: y)
//        }
        
        holesPlayed = Double(numericalScores.count)
        tValue = tCriticalValue(for: Int(holesPlayed) - 1)
        marginOfError = tValue * (sigma / sqrt(holesPlayed))
        
        // Estimate the total score for forecasted holes
        holesToForecast = Double(roundSession.numberOfHoles)
        lowerEstimateForecast = mu * holesToForecast - marginOfError
        upperEstimateForecast = mu * holesToForecast + marginOfError
        
        // If the range is below par, reverse the values.
        lowerRange = abs(lowerEstimateForecast) > abs(upperEstimateForecast) ? upperEstimateForecast : lowerEstimateForecast
        upperRange = abs(upperEstimateForecast) > abs(lowerEstimateForecast) ? upperEstimateForecast : lowerEstimateForecast
        
        print("compute scoring probabilities")
        scoreProbabilities.removeAll()
        let tolerance = 1 / 1E3
        for i in -18...36 {
            let p = targetProbability(for: i)
            if p > tolerance && p < (1 - tolerance) * 100 {
                scoreProbabilities.append((x: Double(i), y: p))
            }
        }
        
        print("\(#function) FINISH")
    }
    
    func mean(scores: [Int]) -> Double {
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
    
    func standardDeviation(scores: [Int], mean: Double) -> Double {
        let variance = scores.reduce(0) { $0 + pow(Double($1) - mean, 2) } / Double(scores.count)
        return sqrt(variance)
    }
    
    func normalDistribution(x: Double, mean: Double, standardDeviation: Double) -> Double {
        let exponent = -pow(x - mean, 2) / (2 * pow(standardDeviation, 2))
        return (1 / (standardDeviation * sqrt(2 * Double.pi))) * exp(exponent)
    }
    
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
    
    func normalCDF(z: Double) -> Double {
        return 0.5 * (1.0 + Darwin.erf(z / sqrt(2.0)))
    }
        
    func probability(for score: PlayerScore, using mu: Double, _ sigma: Double) -> Double {
        switch score {
        case .albatross:    return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -3.49, x2: -2.5)
        case .eagle:        return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -2.49, x2: -1.5)
        case .birdie:       return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -1.49, x2: -0.5)
        case .par:          return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: -0.49, x2: 0.49)
        case .bogey:        return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 0.5, x2: 1.49)
        case .double:       return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 1.5, x2: 2.49)
        case .triple:       return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 2.5, x2: 3.49)
        case .quad:         return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 3.5, x2: 4.49)
        case .quin:         return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 4.5, x2: 5.49)
        case .sex:          return areaUnderNormalCurve(mu: mu, sigma: sigma, x1: 5.5, x2: 6.49)
        case .none:         return 0.0
        }
    }
    
    func areaUnderNormalCurve(mu: Double, sigma: Double, x1: Double, x2: Double) -> Double {
        let z1 = (x1 - mu) / sigma
        let z2 = (x2 - mu) / sigma
        let area = normalCDF(z: z2) - normalCDF(z: z1)
        return area
    }
    

    
    func targetProbability(for total: Int) -> Double {
        print(#function)
        let holesRemaining = holesToForecast - holesPlayed
        let currentTotal = scores.compactMap({ $0.numericalValue }).reduce(0, +)
        let meanTotal = mu * holesRemaining
        let scoreMargin = Double(total - currentTotal)
        let z = (scoreMargin - meanTotal) / sigma * sqrt(holesRemaining)
        let p = normalCDF(z: z) * 100
        
        return p//min(99.99, max(0.01, p))
    }
    
    //    func erf(_ x: Double) -> Double {
    //        // Approximation of the error function
    //        let sign = x < 0 ? -1 : 1
    //        let a1 =  0.254829592
    //        let a2 = -0.284496736
    //        let a3 =  1.421413741
    //        let a4 = -1.453152027
    //        let a5 =  1.061405429
    //        let p  =  0.3275911
    //
    //        let t = 1.0 / (1.0 + p * abs(x))
    //        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-x * x)
    //
    //        return Double(sign) * y
    //    }
}

struct LeaderboardBellCurve_Previews: PreviewProvider {
    static var app = AppSessionV2()
    static var purchase = PurchaseStore()
    static var round = RoundSession()
    
    static var previews: some View {
        VStack {
            Spacer(minLength: 0)
            
            LeaderboardBellCurve()
                .padding(20)
            
            Spacer(minLength: 0)
        }
        .background(Color.systemBackground)
        .environmentObject(app)
        .environmentObject(purchase)
        .environmentObject(round)
        .holisticPreview()
        .onAppear() {
            round.holeRange = [1,2,3,4,5,6,7,8,9]//,10,11,12,13,14,15,16,17,18]
            round.startingHole = 8
            round.numberOfHoles = 9
            var kyle = kPlayerKyle
            kyle.score = [1: "triple", 2: "birdie", 3: "par", 4: "double", 5: "eagle", 6: "bogey", 7: "bogey", 8: "double", 9: "par"]
            
            var sarah = kPlayerSarah
            sarah.score = [1: "birdie", 2: "par", 3: "double", 4: "double", 5: "par", 6: "par", 7: "bogey", 8: "double", 9: "double"]
            
            var murphy = kPlayerMurphy
            murphy.score = [1: "bogey", 2: "bogey", 3: "par", 4: "double", 5: "par", 6: "birdie", 7: "double", 8: "birdie", 9: "par"]
            
            var pablo = kPlayerPablo
            pablo.score = [1: "double", 2: "par", 3: "par", 4: "par", 5: "bogey", 6: "par", 7: "birdie", 8: "bogey", 9: "double"]
            
            round.players = [kyle, sarah, murphy, pablo]
        }
    }
}
