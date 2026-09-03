//
//  MatchupMomentumCard.swift
//  Hackers
//

import Charts
import SwiftUI

struct MatchupMomentumCard: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var selectedProbabilityHole: Int?

    let probabilityTimeline: MatchupProbabilityTimeline?
    let currentProbability: MatchupProbability?
    let scoreTimeline: [MatchupScoreTrendPoint]
    let leftName: String
    let rightName: String
    let leftColor: Color
    let rightColor: Color
    let probabilityBasis: ScoreBasis
    let displayedScoreBasis: ScoreBasis
    let isPointsFormat: Bool
    let isFinal: Bool
    let isLoading: Bool
    let palette: DesignPalette

    private var probabilityPoints: [MatchupProbabilityTrendPoint] {
        probabilityTimeline?.points ?? []
    }

    private var selectedProbabilityPoint: MatchupProbabilityTrendPoint? {
        guard let selectedProbabilityHole else { return nil }
        return probabilityPoints.min {
            abs($0.holesCompleted - selectedProbabilityHole)
                < abs($1.holesCompleted - selectedProbabilityHole)
        }
    }

    private var unsupportedReason: String? {
        probabilityTimeline?.unsupportedReason ?? currentProbability?.unsupportedReason
    }

    private var probabilityBasisLabel: String {
        probabilityBasis == .net ? "Net" : "Gross"
    }

    private var scoreBasisLabel: String {
        displayedScoreBasis == .net ? "Net" : "Gross"
    }

    private var leadChangeCount: Int {
        var previousSign = 0
        var changes = 0
        for point in scoreTimeline where !MatchupScoreComparison.totalsMatch(point.leftAdvantage, 0) {
            let sign = point.leftAdvantage > 0 ? 1 : -1
            if previousSign != 0, sign != previousSign {
                changes += 1
            }
            previousSign = sign
        }
        return changes
    }

    private var largestLead: Double {
        scoreTimeline.map { abs($0.leftAdvantage) }.max() ?? 0
    }

    private var tiedCheckpoints: Int {
        scoreTimeline.count {
            MatchupScoreComparison.totalsMatch($0.leftAdvantage, 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isFinal ? "Win probability replay" : "Win probability")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text(
                    probabilityPoints.count > 1
                        ? "Expected share from 50–50 · ties split evenly"
                        : "\(probabilityBasisLabel) competition forecast"
                )
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
            }

            if let probability = currentProbability, probability.isSupported {
                VStack(spacing: 10) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(leftColor)
                                .frame(width: probabilityWidth(probability.leftWin, total: geometry.size.width))
                            Rectangle()
                                .fill(Color.neutral4)
                                .frame(width: probabilityWidth(probability.tie, total: geometry.size.width))
                            Rectangle()
                                .fill(rightColor)
                                .frame(width: probabilityWidth(probability.rightWin, total: geometry.size.width))
                        }
                        .frame(width: geometry.size.width, height: 10)
                        .clipShape(Capsule())
                    }
                    .frame(height: 10)

                    HStack(spacing: 8) {
                        Text("\(probability.leftWin)% \(leftName)")
                            .foregroundStyle(leftColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Tie \(probability.tie)%")
                            .foregroundStyle(Color.neutral)
                        Text("\(rightName) \(probability.rightWin)%")
                            .foregroundStyle(rightColor)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .contentTransition(.numericText())
                }
                .animation(accessibilityReduceMotion ? nil : .easeInOut(duration: 0.25), value: probability)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Current \(probabilityBasisLabel.lowercased()) win probability: \(leftName) \(probability.leftWin) percent, tie \(probability.tie) percent, \(rightName) \(probability.rightWin) percent"
                )
            }

            if probabilityPoints.count > 1 {
                Chart {
                    RuleMark(y: .value("Even matchup", 50))
                        .foregroundStyle(Color.neutral2)
                        .lineStyle(.init(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .leading, alignment: .center) {
                            Text("50–50")
                                .fontStyle(kFontName, size: 9, weight: .semibold)
                                .foregroundStyle(Color.neutral)
                        }

                    ForEach(probabilityPoints) { point in
                        AreaMark(
                            x: .value("Holes completed", point.holesCompleted),
                            yStart: .value("Even matchup", 50),
                            yEnd: .value("Expected share", point.leftExpectedShare)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [rightColor.opacity(0.3), leftColor.opacity(0.3)],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )

                        LineMark(
                            x: .value("Holes completed", point.holesCompleted),
                            y: .value("Expected share", point.leftExpectedShare)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [rightColor, leftColor],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Holes completed", point.holesCompleted),
                            y: .value("Expected share", point.leftExpectedShare)
                        )
                        .foregroundStyle(point.leftExpectedShare >= 50 ? leftColor : rightColor)
                        .symbolSize(selectedProbabilityPoint?.id == point.id ? 80 : 34)
                    }

                    if let selectedProbabilityPoint {
                        RuleMark(
                            x: .value(
                                "Selected checkpoint",
                                selectedProbabilityPoint.holesCompleted
                            )
                        )
                        .foregroundStyle(palette.foregroundColor.opacity(0.7))
                        .lineStyle(.init(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine().foregroundStyle(Color.neutral5.opacity(0.25))
                        AxisValueLabel {
                            if let holes = value.as(Int.self) {
                                Text(holes == 0 ? "Start" : "\(holes)")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine().foregroundStyle(Color.neutral5.opacity(0.25))
                        AxisValueLabel {
                            if let probability = value.as(Int.self) {
                                Text("\(probability)%")
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXSelection(value: $selectedProbabilityHole)
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(probabilityReplayAccessibilityLabel)

                if let selectedProbabilityPoint {
                    selectedCheckpointSummary(selectedProbabilityPoint)
                } else {
                    Text("Tap or drag across the chart to inspect a checkpoint")
                        .fontStyle(kFontName, size: 11, weight: .regular)
                        .foregroundStyle(Color.neutral)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Replaying each scoring checkpoint…")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                }
                .foregroundStyle(Color.neutral)
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityElement(children: .combine)
            } else if scoreTimeline.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(scoreBasisLabel) score advantage")
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)

                    Chart {
                        RuleMark(y: .value("Tied", 0))
                            .foregroundStyle(Color.neutral2)
                            .lineStyle(.init(lineWidth: 1, dash: [3, 4]))

                        ForEach(scoreTimeline) { point in
                            LineMark(
                                x: .value("Holes completed", point.holesCompleted),
                                y: .value("Left advantage", point.leftAdvantage)
                            )
                            .foregroundStyle(leftColor)
                            .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))

                            PointMark(
                                x: .value("Holes completed", point.holesCompleted),
                                y: .value("Left advantage", point.leftAdvantage)
                            )
                            .foregroundStyle(point.leftAdvantage >= 0 ? leftColor : rightColor)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 190)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(scoreReplayAccessibilityLabel)
                }
            } else {
                Label(
                    unsupportedReason ?? "Record scores to start the matchup trend.",
                    systemImage: "chart.line.uptrend.xyaxis"
                )
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            }

            if scoreTimeline.isPopulated {
                Divider()

                HStack(spacing: 12) {
                    metric(title: "Lead changes", value: "\(leadChangeCount)")
                    metric(title: "Largest lead", value: formattedMargin(largestLead))
                    metric(title: "Times tied", value: "\(tiedCheckpoints)")
                }
            }

            if let unsupportedReason, scoreTimeline.count > 1 {
                Label(unsupportedReason, systemImage: "info.circle")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let confidence = currentProbability?.confidence {
                Text("\(confidence.rawValue.capitalized) confidence · updates as scores are recorded")
                    .fontStyle(kFontName, size: 11, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .fontStyle(kFontName, size: 18, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .contentTransition(.numericText())
            Text(title.uppercased())
                .fontStyle(kFontName, size: 9, weight: .medium)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func selectedCheckpointSummary(
        _ point: MatchupProbabilityTrendPoint
    ) -> some View {
        VStack(spacing: 8) {
            Text(point.holesCompleted == 0 ? "Opening forecast" : "Through \(point.holesCompleted) holes")
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral)

            HStack(spacing: 8) {
                checkpointValue(name: leftName, value: point.leftWin, color: leftColor)
                checkpointValue(name: "Tie", value: point.tie, color: Color.neutral2)
                checkpointValue(name: rightName, value: point.rightWin, color: rightColor)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func checkpointValue(name: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)%")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(name)
                .fontStyle(kFontName, size: 9, weight: .medium)
                .foregroundStyle(Color.neutral)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func probabilityWidth(_ percentage: Int, total: CGFloat) -> CGFloat {
        total * CGFloat(max(0, min(100, percentage))) / 100
    }

    private func formattedMargin(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let number = rounded.formatted(.number.precision(.fractionLength(0...1)))
        if MatchupScoreComparison.totalsMatch(rounded, 0) { return "Even" }
        if isPointsFormat { return "\(number) pts" }
        return "\(number) strokes"
    }

    private var probabilityReplayAccessibilityLabel: String {
        guard let first = probabilityPoints.first, let last = probabilityPoints.last else {
            return "Win probability replay unavailable"
        }
        return "Win probability replay from the start through \(last.holesCompleted) holes. \(leftName) moved from \(first.leftWin) to \(last.leftWin) percent. \(rightName) moved from \(first.rightWin) to \(last.rightWin) percent."
    }

    private var scoreReplayAccessibilityLabel: String {
        guard let last = scoreTimeline.last else { return "Score advantage replay unavailable" }
        let leader: String
        if MatchupScoreComparison.totalsMatch(last.leftAdvantage, 0) {
            leader = "The match is tied"
        } else if last.leftAdvantage > 0 {
            leader = "\(leftName) leads by \(formattedMargin(abs(last.leftAdvantage)))"
        } else {
            leader = "\(rightName) leads by \(formattedMargin(abs(last.leftAdvantage)))"
        }
        return "Score advantage through \(last.holesCompleted) holes. \(leader)."
    }
}
