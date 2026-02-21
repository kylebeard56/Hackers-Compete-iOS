//
//  ScorecardSheet.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct ScorecardSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant
    
    @State private var selectedParticipantID: String?
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var effectiveAccent: Color {
        viewModel.hasTeamColorMatchingTheme ? palette.foregroundColor : viewModel.theme.color
    }
    
    private var activeParticipant: RoundParticipant {
        viewModel.snapshot.participants.first(where: { $0.id == selectedParticipantID }) ?? participant
    }
    
    private var scoreLabel: String {
        viewModel.formattedScoreToPar(viewModel.scoreToPar(for: activeParticipant, basis: viewModel.scoreBasis))
    }
    
    private var displayedHoles: [Int] {
        viewModel.holeNumbers
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                scorecardSection
                leaderboardSection
            }
            .padding(16)
        }
        .background(palette.backgroundColor)
        .onAppear {
            if selectedParticipantID == nil {
                selectedParticipantID = participant.id
            }
        }
    }
}

private extension ScorecardSheet {
    
    // MARK: - Header
    
    var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text(activeParticipant.name.fullName)
                    .fontStyle(kFontName, size: 22, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer(minLength: 0)
                
                Text(scoreLabel)
                    .fontStyle(kFontName, size: 22, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            
            HStack(spacing: 8) {
                if let team = viewModel.team(for: activeParticipant) {
                    Text(team.name)
                        .fontStyle(kFontName, size: 12, weight: .semibold)
                        .foregroundStyle(team.teamColor.value)
                    Dot()
                }
                
                Text("\(activeParticipant.adjustedHandicap) HCP")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
            }
        }
    }
    
    // MARK: - Scorecard
    
    var scorecardSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Scorecard")
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
                
                if viewModel.handicapsEnabled {
                    Menu {
                        Button("Gross") { viewModel.scoreBasis = .gross }
                        Button("Net") { viewModel.scoreBasis = .net }
                    } label: {
                        Text(viewModel.scoreBasis == .gross ? "Gross" : "Net")
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(palette.foregroundColor)
                            .caretChip()
                            .glassCardEffect(shape: .capsule)
                    }
                    .onTapGesture {
                        Haptics.fire(.light)
                    }
                }
            }
            
            ZStack(alignment: .leading) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(displayedHoles, id: \.self) { holeNumber in
                            scorecardHoleColumn(holeNumber: holeNumber)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.leading, titleColumnTotalWidth)
                }
                .padding(.trailing, -16)
                
                scorecardTitleColumn
                    .background(palette.cardColor)
            }
        }
        .padding(16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Leaderboard
    
    var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Leaderboard")
                .fontStyle(kFontName, size: 16, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.leaderboardRows) { row in
                        leaderboardCard(row: row)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 16)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -16)
        }
        .padding(16)
        .background(palette.cardColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    var scorecardTitleColumn: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            titleCell("Hole", height: holeRowHeight)
            titleCell("Yards", height: yardRowHeight)
            titleCell("HCP", height: handicapRowHeight)
            titleCell("Par", height: parRowHeight)
            titleCell("Score", height: scoreRowHeight)
            titleCell("Place", height: placeRowHeight)
        }
        .padding(.vertical, columnPaddingVertical)
        .frame(width: titleColumnTotalWidth, height: scorecardColumnHeight, alignment: .leading)
        .padding(.trailing, titleColumnSpacing)
    }
    
    func scorecardHoleColumn(holeNumber: Int) -> some View {
        let hole = viewModel.hole(for: holeNumber)
        let gross = viewModel.grossStrokes(for: activeParticipant.id, holeNumber: holeNumber)
        let net = viewModel.netStrokesOnHole(participant: activeParticipant, holeNumber: holeNumber)
        let strokesReceived = viewModel.strokesReceivedOnHole(participant: activeParticipant, holeNumber: holeNumber)
        let place = placeSummary(for: holeNumber)
        let highlight = holeNumber == currentHoleNumber(for: activeParticipant)
        
        return ZStack {
            if highlight {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.neutral6.opacity(0.6))
            }
            
            VStack(spacing: rowSpacing) {
                valueCell("\(holeNumber)", height: holeRowHeight, color: palette.foregroundColor)
                valueCell(hole.map { "\($0.yardage)" } ?? "—", height: yardRowHeight, color: palette.foregroundColor)
                handicapCell(hole?.handicap, height: handicapRowHeight)
                valueCell(hole.map { "\($0.par)" } ?? "—", height: parRowHeight, color: palette.foregroundColor)
                scoreCell(
                    holeNumber: holeNumber,
                    par: hole?.par,
                    gross: gross,
                    net: net,
                    strokesReceived: strokesReceived,
                    height: scoreRowHeight
                )
                placeCell(place, height: placeRowHeight)
            }
            .padding(.vertical, columnPaddingVertical)
        }
        .frame(width: holeColumnWidth, height: scorecardColumnHeight)
    }
    
    func titleCell(_ value: String, height: CGFloat) -> some View {
        Text(value.uppercased())
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(height: height, alignment: .leading)
    }
    
    func valueCell(_ value: String, height: CGFloat, color: Color) -> some View {
        Text(value)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(color)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
    
    func handicapCell(_ handicap: Int?, height: CGFloat) -> some View {
        let value = handicap.map(String.init) ?? "—"
        let color = handicap.map(handicapColor) ?? Color.neutral4
        
        return Text(value)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(color)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
    
    func scoreCell(
        holeNumber: Int,
        par: Int?,
        gross: Int?,
        net: Int?,
        strokesReceived: Int,
        height: CGFloat
    ) -> some View {
        let displayed = viewModel.scoreBasis == .gross ? gross : net
        let isScored = gross != nil
        let value = isScored ? "\(displayed ?? 0)" : "0"
        let textColor = isScored ? palette.foregroundColor : Color.neutral4
        
        return ZStack {
            scoreDecoration(par: par, strokes: displayed)
            Text(value)
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(textColor)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .center)
        .overlay(alignment: .trailing) {
            if strokesReceived > 0 {
                VStack(spacing: 4) {
                    ForEach(0..<strokesReceived, id: \.self) { _ in
                        Circle()
                            .fill(palette.foregroundColor)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: height)
                .padding(.trailing, 6)
            }
        }
    }
    
    func placeCell(_ place: HolePlaceSummary?, height: CGFloat) -> some View {
        let isEmpty = place == nil
        let label = place?.label ?? "—"
        
        return HStack(spacing: 4) {
            Text(label)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(isEmpty ? Color.neutral4 : palette.foregroundColor)
            
            if let movement = place?.movement {
                movementIndicator(movement)
                .foregroundStyle(movement > 0 ? effectiveAccent : Color.systemError)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    func movementIndicator(_ movement: Int) -> some View {
        let arrow = Icon(
            name: movement > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill",
            size: 6,
            weight: .bold
        ).frame(height: 6)
        
        let value = Text("\(abs(movement))")
            .fontStyle(kFontName, size: 8, weight: .semibold)
            .frame(height: 8)
        
        return VStack(spacing: movement > 0 ? 1 : 0) {
//            arrow
//            value
            if movement < 0 {
                value
                arrow
            } else {
                arrow
                value
            }
        }
    }
    
    func scoreDecoration(par: Int?, strokes: Int?) -> some View {
        guard let par, let strokes else { return AnyView(EmptyView()) }
        let diff = strokes - par
        let strokeColor = Color.neutral5
        
        if diff <= -2 {
            return AnyView(
                Circle()
                    .fill(strokeColor.opacity(0.7))
                    .frame(width: 28, height: 28)
            )
        } else if diff == -1 {
            return AnyView(
                Circle()
                    .stroke(strokeColor, lineWidth: 2)
                    .frame(width: 28, height: 28)
            )
        } else if diff == 1 {
            return AnyView(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(strokeColor, lineWidth: 2)
                    .frame(width: 28, height: 28)
            )
        } else if diff >= 2 {
            return AnyView(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(strokeColor.opacity(0.7))
                    .frame(width: 28, height: 28)
            )
        }
        
        return AnyView(EmptyView())
    }
    
    @ViewBuilder
    func leaderboardCard(row: LiveRoundViewModel.LeaderboardRow) -> some View {
        let scoreLabel = viewModel.formattedScoreToPar(row.scoreToPar)
        let placeLabel = row.placeLabel.replacingOccurrences(of: ".", with: "")
        let teamColor = viewModel.teamColor(for: row.participant)
        let avatarColor = teamColor ?? Color.neutral6
        let currentHole = currentHoleLabel(thru: row.thru)
        let participantHoleNumber = currentHoleNumber(for: row.participant)
        let strokesReceived = participantHoleNumber.map {
            viewModel.strokesReceivedOnHole(participant: row.participant, holeNumber: $0)
        } ?? 0
        let showHandicapDots = viewModel.snapshot.configuration.useHandicaps && strokesReceived > 0
        let dotColor: Color = viewModel.snapshot.requiresTeams ? (teamColor ?? .neutral2) : palette.foregroundColor
        let isSelected = row.participant.id == activeParticipant.id
        
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(placeLabel)
                    .fontStyle(kFontName, size: 11, weight: .semibold)
                    .foregroundStyle(Color.neutral2)
                
                Spacer(minLength: 0)
                
                Text(scoreLabel)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            
            HStack(spacing: 10) {
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(avatarColor)
                            .frame(width: 40, height: 40)
                        
                        Text(row.participant.name.initials)
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(Color.white)
                    }
                    
                    if showHandicapDots {
                        handicapDots(strokesReceived: strokesReceived, dotColor: dotColor, dotSize: 6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortName(for: row.participant))
                        .fontStyle(kFontName, size: 13, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    
                    Text(currentHole)
                        .fontStyle(kFontName, size: 10, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                }
            }
        }
        .padding(12)
        .frame(width: 180)
        //.background(palette.backgroundColor)
        //.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassCardEffect(cornerRadius: 16, interactive: false)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black, lineWidth: 2)
            }
        }
        .onTapGesture {
            Haptics.fire(.light)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedParticipantID = row.participant.id
            }
        }
    }
    
    func currentHoleLabel(thru: Int) -> String {
        guard let last = displayedHoles.last else { return "HOLE —" }
        if thru >= last { return "FINISHED" }
        return "HOLE \(min(last, thru + 1))"
    }
    
    func shortName(for participant: RoundParticipant) -> String {
        let given = participant.name.givenName
        let family = participant.name.familyName
        guard given.isPopulated, family.isPopulated else { return participant.name.fullName }
        return "\(given.prefix(1)). \(family)"
    }
    
    func handicapColor(_ handicap: Int) -> Color {
        let clamped = min(max(handicap, 1), 18)
        let fraction = Double(clamped - 1) / 17.0
        return Color.systemError.interpolate(to: effectiveAccent, fraction: fraction)
    }
    
    @ViewBuilder
    func handicapDots(strokesReceived: Int, dotColor: Color, dotSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        dotColor,
                        lineWidth: index < strokesReceived ? 0 : 1
                    )
                    .background(
                        Circle()
                            .fill(index < strokesReceived ? dotColor : .clear)
                    )
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
    
    func placeSummary(for holeNumber: Int) -> HolePlaceSummary? {
        guard isScored(holeNumber: holeNumber, participant: activeParticipant) else { return nil }
        let current = placesByParticipant(for: holeNumber)[activeParticipant.id]
        guard let current else { return nil }
        
        let previousHole = previousScoredHole(before: holeNumber)
        var movement: Int?
        
        if let previousHole, let previous = placesByParticipant(for: previousHole)[activeParticipant.id] {
            let delta = previous.place - current.place
            if delta != 0 { movement = delta }
        }
        
        return HolePlaceSummary(label: current.label, place: current.place, movement: movement)
    }
    
    func previousScoredHole(before holeNumber: Int) -> Int? {
        displayedHoles
            .filter { $0 < holeNumber }
            .filter { isScored(holeNumber: $0, participant: participant) }
            .last
    }
    
    func isScored(holeNumber: Int, participant: RoundParticipant) -> Bool {
        viewModel.grossStrokes(for: participant.id, holeNumber: holeNumber) != nil
    }
    
    func placesByParticipant(for holeNumber: Int) -> [String: (label: String, place: Int)] {
        let rows = viewModel.snapshot.participants.compactMap { participant -> PlaceRow? in
            guard isScored(holeNumber: holeNumber, participant: participant) else { return nil }
            let score = scoreToParThroughHole(participant: participant, holeNumber: holeNumber)
            return PlaceRow(participant: participant, scoreToPar: score)
        }
        
        let ordered = rows.sorted {
            if $0.scoreToPar != $1.scoreToPar { return $0.scoreToPar < $1.scoreToPar }
            return $0.participant.alphabeticName < $1.participant.alphabeticName
        }
        
        var labels: [String: (label: String, place: Int)] = [:]
        var place = 1
        var index = 0
        
        while index < ordered.count {
            let score = ordered[index].scoreToPar
            var group: [PlaceRow] = []
            
            while index < ordered.count, ordered[index].scoreToPar == score {
                group.append(ordered[index])
                index += 1
            }
            
            let label = group.count > 1 ? "T-\(place)" : "\(place)"
            for row in group {
                labels[row.participant.id] = (label, place)
            }
            
            place += group.count
        }
        
        return labels
    }
    
    func scoreToParThroughHole(participant: RoundParticipant, holeNumber: Int) -> Int {
        var sum = 0
        for hole in displayedHoles where hole <= holeNumber {
            guard let par = viewModel.hole(for: hole)?.par else { continue }
            guard let gross = viewModel.grossStrokes(for: participant.id, holeNumber: hole) else { continue }
            switch viewModel.scoreBasis {
            case .gross:
                sum += (gross - par)
            case .net:
                let received = viewModel.strokesReceivedOnHole(participant: participant, holeNumber: hole)
                sum += ((gross - received) - par)
            }
        }
        return sum
    }
    
    struct PlaceRow {
        let participant: RoundParticipant
        let scoreToPar: Int
    }
    
    struct HolePlaceSummary {
        let label: String
        let place: Int
        let movement: Int?
    }
    
    var rowSpacing: CGFloat { 10 }
    var titleColumnWidth: CGFloat { 48 }
    var titleColumnSpacing: CGFloat { 12 }
    var titleColumnTotalWidth: CGFloat { titleColumnWidth }
    var holeColumnWidth: CGFloat { 56 }
    var holeRowHeight: CGFloat { 22 }
    var yardRowHeight: CGFloat { 22 }
    var handicapRowHeight: CGFloat { 22 }
    var parRowHeight: CGFloat { 22 }
    var scoreRowHeight: CGFloat { 34 }
    var placeRowHeight: CGFloat { 28 }
    var columnPaddingVertical: CGFloat { 6 }
    var scorecardColumnHeight: CGFloat {
        holeRowHeight
        + yardRowHeight
        + handicapRowHeight
        + parRowHeight
        + scoreRowHeight
        + placeRowHeight
        + (rowSpacing * 5)
        + (columnPaddingVertical * 2)
    }
    
    func currentHoleNumber(for participant: RoundParticipant) -> Int? {
        displayedHoles.first(where: { viewModel.grossStrokes(for: participant.id, holeNumber: $0) == nil })
    }
}

// MARK: - Preview

#Preview("Scorecard Sheet") {
    ZStack {
        GolfTopology()
            .frame(width: UIScreen.main.bounds.width)
            .sheet(isPresented: .true) {
                ScorecardSheetPreview()
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.thinMaterial)
                    //.sizedSheetDetent()
            }
    }
}

private struct ScorecardSheetPreview: View {
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant
    
    init() {
        var snapshot = MockLiveRoundRyderCup.snapshot
        snapshot.scoring = Self.makePreviewScores(snapshot: snapshot)
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id
        
        let roundSession = RoundSession()
        roundSession.snapshot = snapshot
        
        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        
        _viewModel = StateObject(wrappedValue: vm)
        participant = snapshot.participants.first!
    }
    
    var body: some View {
        ScorecardSheet(viewModel: viewModel, participant: participant)
    }
    
    private static func makePreviewScores(snapshot: RoundSnapshot) -> [ScoreEntry] {
        let holes = snapshot.defaultTee?.holes ?? snapshot.tees.first?.holes
        guard let holes else { return [] }
        let participants = snapshot.participants
        let scoredHoles = holes.prefix(14)
        let segmentID = "segment_preview"
        
        return participants.enumerated().flatMap { index, participant in
            scoredHoles.compactMap { hole in
                let offset = ((index + hole.number) % 4) - 1
                let strokes = max(1, hole.par + offset)
                return ScoreEntry(
                    id: ScoreEntry.makeID(hole: hole.number, segment: segmentID, scoringUnit: participant.id),
                    holeNumber: hole.number,
                    segmentID: segmentID,
                    groupID: participant.groupID ?? "group_1",
                    scoringUnitID: participant.id,
                    participantIDs: [participant.id],
                    strokes: strokes,
                    pickedUp: false,
                    entryID: participant.id,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: snapshot.round.id
                )
            }
        }
    }
}
