//
//  IndividualScorecardView.swift
//  Hackers
//
//  Read-only individual scorecard for a single participant.
//

import SwiftUI

struct IndividualScorecardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }
    private var holeNumbers: [Int] { viewModel.holeNumbers }
    private var handicapsEnabled: Bool { viewModel.handicapsEnabled }
    private var scoreBasis: ScoreBasis { viewModel.scoreBasis }

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: .yellow)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    navPadding

                    playerHeader
                    totalScoreCallout
                    frontNineTile
                    backNineTile
                }
                .padding(.horizontal, 16)
                .padding(.top, UIApplication.shared.topSafeAreaInset)
                .padding(.bottom, 60)
            }

            scorecardNavHeader
                .padding(.horizontal, 16)
                .alignTop()
        }
        .navigationBarBackButtonHidden(true)
    }

    private var navPadding: some View {
        scorecardNavHeader
            .disabled(true)
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var scorecardNavHeader: some View {
        HStack(spacing: 12) {
            NavButton(style: .glass, icon: "f00d", color: palette.foregroundColor) {
                dismiss()
            }

            Spacer(minLength: 0)

            Text("Scorecard".uppercased())
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    private var playerHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            PlayerAvatarView(
                initials: participantInitials,
                size: 48,
                glassTint: Color.accentYellow.opacity(0.3)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(participantName)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                if handicapsEnabled {
                    Text("HCP \(participant.adjustedHandicap)")
                        .fontStyle(kFontName, size: 13, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }

            Spacer(minLength: 0)

            Logo()
                .frame(height: 28)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }

    private var totalScoreCallout: some View {
        HStack(spacing: 8) {
            if handicapsEnabled {
                Text("Score \(totalGross)/\(totalNet)")
                    .fontStyle(kFontName, size: 18, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)
            } else {
                Text("Score \(totalGross)")
                    .fontStyle(kFontName, size: 18, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCardEffect(interactive: false)
    }

    @ViewBuilder
    private var frontNineTile: some View {
        let holes = Array(holeNumbers.prefix(9))
        if holes.isPopulated {
            scorecardTile(holes: holes, label: "Out")
        }
    }

    @ViewBuilder
    private var backNineTile: some View {
        let holes = Array(holeNumbers.suffix(9))
        if holes.isPopulated {
            scorecardTile(holes: holes, label: "In")
        }
    }

    private func scorecardTile(holes: [Int], label: String) -> some View {
        VStack(spacing: 8) {
            scorecardHeaderRow(holes: holes, label: label)
            scorecardParRow(holes: holes)
            scorecardYardsRow(holes: holes)
            scorecardHcpRow(holes: holes)
            scorecardScoreRow(holes: holes)
            if handicapsEnabled {
                scorecardNetRow(holes: holes)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }

    private func scorecardHeaderRow(holes: [Int], label: String) -> some View {
        HStack(spacing: 4) {
            Text("Hole")
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .frame(width: 36, alignment: .leading)
            ForEach(holes, id: \.self) { h in
                Text("\(h)")
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(maxWidth: .infinity)
            }
            Text(label)
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .frame(width: 36)
        }
    }

    private func scorecardParRow(holes: [Int]) -> some View {
        let values = holes.map { "\(viewModel.hole(for: $0)?.par ?? 0)" }
        let total = holes.reduce(0) { $0 + (viewModel.hole(for: $1)?.par ?? 0) }
        return scorecardValueRow(label: "Par", values: values, total: total)
    }

    private func scorecardYardsRow(holes: [Int]) -> some View {
        let values = holes.map { viewModel.hole(for: $0).map { "\($0.yardage)" } ?? "—" }
        let total = holes.reduce(0) { $0 + (viewModel.hole(for: $1)?.yardage ?? 0) }
        return scorecardValueRow(label: "Yds", values: values, total: total)
    }

    private func scorecardHcpRow(holes: [Int]) -> some View {
        let values = holes.map { viewModel.hole(for: $0).flatMap { $0.handicap.map(String.init) } ?? "—" }
        return scorecardValueRow(label: "HCP", values: values, total: nil)
    }

    private func scorecardScoreRow(holes: [Int]) -> some View {
        let values = holes.map { holeNum -> String in
            guard let gross = viewModel.grossStrokes(for: participant.id, holeNumber: holeNum) else {
                return "—"
            }
            return "\(gross)"
        }
        let total = holes.compactMap {
            viewModel.grossStrokes(for: participant.id, holeNumber: $0)
        }.reduce(0, +)
        return scorecardValueRow(label: "Score", values: values, total: total, holes: holes, highlightScores: true)
    }

    private func scorecardNetRow(holes: [Int]) -> some View {
        let values = holes.map { holeNum -> String in
            guard let net = viewModel.netStrokesOnHole(participant: participant, holeNumber: holeNum) else {
                return "—"
            }
            return "\(net)"
        }
        let total = holes.compactMap {
            viewModel.netStrokesOnHole(participant: participant, holeNumber: $0)
        }.reduce(0, +)
        return scorecardValueRow(label: "Net", values: values, total: total)
    }

    private func scorecardValueRow(
        label: String,
        values: [String],
        total: Int?,
        holes: [Int]? = nil,
        highlightScores: Bool = false
    ) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral2)
                .frame(width: 36, alignment: .leading)
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let holeNum = holes?[index]
                let par = holeNum.flatMap { viewModel.hole(for: $0)?.par } ?? 4
                let strokes = Int(value)
                let isUnderPar = strokes != nil && strokes! < par
                let isOverPar = strokes != nil && strokes! > par
                let bgColor: Color? = highlightScores ? (isUnderPar ? Color.accentGreen.opacity(0.25) : (isOverPar ? Color.systemRed.opacity(0.15) : nil)) : nil

                Text(value)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(bgColor)
                    .cornerRadius(4)
            }
            Group {
                if let total {
                    Text("\(total)")
                        .fontStyle(kFontName, size: 13, weight: .bold)
                        .foregroundStyle(palette.foregroundColor)
                } else {
                    Text("—")
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                }
            }
            .frame(width: 36)
        }
    }

    private var participantInitials: String {
        let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = participant.name.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        var initials = ""
        if let g = given.first { initials += String(g) }
        if let f = family.first { initials += String(f) }
        return initials.isEmpty ? "?" : initials.uppercased()
    }

    private var participantName: String {
        participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var totalGross: Int {
        holeNumbers.compactMap {
            viewModel.grossStrokes(for: participant.id, holeNumber: $0)
        }.reduce(0, +)
    }

    private var totalNet: Int {
        holeNumbers.compactMap {
            viewModel.netStrokesOnHole(participant: participant, holeNumber: $0)
        }.reduce(0, +)
    }
}

// MARK: - Preview

#Preview("Front 9, full scored") {
    IndividualScorecardPreviewContainer(snapshot: MockIndividualScorecard.front9Full)
        .preferredColorScheme(.light)
}

#Preview("Back 9, full scored") {
    IndividualScorecardPreviewContainer(snapshot: MockIndividualScorecard.back9Full)
        .preferredColorScheme(.light)
}

#Preview("Full 18, full scored") {
    IndividualScorecardPreviewContainer(snapshot: MockIndividualScorecard.full18Full)
        .preferredColorScheme(.light)
}

#Preview("Full 18, partially scored") {
    IndividualScorecardPreviewContainer(snapshot: MockIndividualScorecard.full18Partial)
        .preferredColorScheme(.light)
}

#Preview("Full 18, dark") {
    IndividualScorecardPreviewContainer(snapshot: MockIndividualScorecard.full18Full)
        .preferredColorScheme(.dark)
}

private struct IndividualScorecardPreviewContainer: View {
    let snapshot: RoundSnapshot
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant

    init(snapshot: RoundSnapshot) {
        self.snapshot = snapshot
        let vm = LiveRoundViewModel()
        vm.set(snapshot: snapshot)
        _viewModel = StateObject(wrappedValue: vm)
        participant = snapshot.participants.first ?? MockParticipants.participant1
    }

    var body: some View {
        IndividualScorecardView(viewModel: viewModel, participant: participant)
            .task(id: snapshot.round.id) {
                viewModel.set(snapshot: snapshot)
            }
    }
}
