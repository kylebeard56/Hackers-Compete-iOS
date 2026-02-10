//
//  FullScorecardView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/9/26.
//

import SwiftUI

struct FullScorecardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant

    @State private var selectedParticipantID: String?
    @State private var horizontalOffset: CGFloat = 0
    @State private var isRotated = false
    private let layout = GridLayout()

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var displayedHoles: [Int] {
        viewModel.holeNumbers
    }

    private var orderedParticipants: [LiveRoundViewModel.LeaderboardRow] {
        viewModel.leaderboardRows
    }

    // MARK: - Main Body ✅
    
    var body: some View {
        GeometryReader { geom in
            let layoutSize = isRotated
                ? CGSize(width: geom.size.height, height: geom.size.width)
                : geom.size

            ZStack {
                palette.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: layout.sectionSpacing) {
                    topBar

                    scorecardGrid(in: layoutSize)
                        .overlay(alignment: .bottom) {
                            scoreBasisToggle
                                .padding(.bottom, layout.toggleBottomPadding)
                        }
                }
                .padding(.top, layout.topPadding)
                .padding(.horizontal, layout.horizontalPadding)
            }
            .rotationEffect(.degrees(isRotated ? 90 : 0))
            .frame(width: layoutSize.width, height: layoutSize.height)
            .position(x: geom.size.width / 2, y: geom.size.height / 2)
            .animation(.easeInOut(duration: 0.25), value: isRotated)
        }
        .onAppear {
            if selectedParticipantID == nil {
                selectedParticipantID = participant.id
            }
        }
    }
}

private extension FullScorecardView {
    // MARK: - Top Bar ✅

    var topBar: some View {
        HStack(spacing: layout.navSpacing) {
            NavButton(style: .glass, onTap: { dismiss() })

            Spacer(minLength: 0)
            
            VStack(spacing: 0) {
                Text(courseName)
                    .fontStyle(.poppins, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 8) {
                    Text(gameFormat)
                    
                    Dot()
                    
                    Text(playerCountLabel)
                }
                .fontStyle(.poppins, size: 11, weight: .medium)
                .foregroundStyle(Color.neutral2)
            }
            
            Spacer(minLength: 0)

            NavButton(
                style: .glass,
                icon: isRotated ? "f066" : "f065",
                weight: .regular,
                color: palette.foregroundColor
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRotated.toggle()
                }
            }
        }
    }

    // MARK: - Scorecrd Grid ⚠️

    func scorecardGrid(in size: CGSize) -> some View {
        let middleWidth = max(0, size.width - layout.totalColumnWidth)

        return ZStack(alignment: .topTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    /// Applies spacing to the main scroll for the "sticky" hole and par values
                    Color.clear
                        .frame(height: headerHeight + layout.rowSpacing)

                    ZStack(alignment: .topLeading) {
                        mainHorizontalScroll(width: middleWidth)

                        totalColumnRows
                            .frame(width: layout.totalColumnWidth)
                            .alignTrailing()

                        if showLeftOverlay {
                            leftOverlayColumn
                                .frame(width: layout.leftOverlayWidth)
                                .alignLeading()
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                //.padding(.bottom, layout.bottomContentPadding)
            }

            headerOverlay(width: middleWidth)
        }
        .background(palette.backgroundColor)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Header Overlay

    func headerOverlay(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            headerScrollContent
                .frame(width: width, alignment: .leading)
                .clipped()
                .offset(x: horizontalOffset)

            totalHeaderColumn
                .frame(width: layout.totalColumnWidth, alignment: .center)
        }
        .padding(.top, layout.headerTopPadding)
//        .background(palette.backgroundColor)
        .glassCardEffect(cornerRadius: 0, interactive: false)
    }

    var headerScrollContent: some View {
        VStack(spacing: layout.rowSpacing) {
            headerRow(leading: "Hole", values: displayedHoles.map { "\($0)" }, height: layout.headerHoleHeight)
            headerRow(leading: "Par", values: displayedHoles.map { parLabel(for: $0) }, height: layout.headerParHeight)
        }
    }

    var totalHeaderColumn: some View {
        VStack(spacing: layout.rowSpacing) {
            headerLabelCell("Tot", height: layout.headerHoleHeight)
            headerLabelCell(totalParLabel, height: layout.headerParHeight)
        }
    }

    func mainHorizontalScroll(width: CGFloat) -> some View {
        ObservableScrollView(offset: $horizontalOffset, axes: .horizontal, showsIndicators: false) {
            VStack(spacing: layout.rowSpacing) {
                ForEach(Array(detailRows.enumerated()), id: \.offset) { index, row in
                    detailRow(row: row, index: index)
                        .frame(height: rowHeight(for: row))
                }
            }
        }
        .frame(width: width)
        .clipped()
    }

    func detailRow(row: ScorecardRow, index: Int) -> some View {
        let background = rowBackgroundColor(for: row, index: index)

        return HStack(spacing: layout.columnSpacing) {
            labelCell(for: row)
                .frame(width: layout.playerNameColumnWidth)

            ForEach(displayedHoles, id: \.self) { holeNumber in
                detailCell(row: row, holeNumber: holeNumber)
                    .frame(width: layout.cellWidth)
            }
        }
        //.frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture {
            guard case .player(let row) = row else { return }
            Haptics.fire(.light)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedParticipantID = row.participant.id
            }
        }
    }

    func detailCell(row: ScorecardRow, holeNumber: Int) -> some View {
        switch row {
        case .yards:
            let yardage = viewModel.hole(for: holeNumber)?.yardage
            return AnyView(valueCell(yardage.map(String.init) ?? "—", color: palette.foregroundColor))
        case .handicap:
            let value = viewModel.hole(for: holeNumber)?.handicap
            return AnyView(valueCell(value.map(String.init) ?? "—", color: value.map(handicapColor) ?? Color.neutral4))
        case .player(let row):
            let gross = viewModel.grossStrokes(for: row.participant.id, holeNumber: holeNumber)
            let net = viewModel.netStrokesOnHole(participant: row.participant, holeNumber: holeNumber)
            let strokesReceived = viewModel.strokesReceivedOnHole(participant: row.participant, holeNumber: holeNumber)
            let par = viewModel.hole(for: holeNumber)?.par

            return AnyView(
                scoreCell(
                    par: par,
                    gross: gross,
                    net: net,
                    strokesReceived: strokesReceived
                )
            )
        }
    }

    var totalColumnRows: some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(Array(detailRows.enumerated()), id: \.offset) { index, row in
                totalRow(row: row, index: index)
                    .frame(height: rowHeight(for: row))
            }
        }
        .glassCardEffect(cornerRadius: 0, interactive: false)
        //.glassCardEffect(shape: RoundedRectangle(cornerRadius: layout.floatingColumnCornerRadius, style: .continuous), interactive: false)
    }

    func totalRow(row: ScorecardRow, index: Int) -> some View {
        let background = rowBackgroundColor(for: row, index: index)

        return ZStack {
            background

            switch row {
            case .yards, .handicap:
                Text("")
                    //.frame(maxWidth: .infinity, alignment: .center)
            case .player(let row):
                totalScoreLabel(for: row.participant)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard case .player(let row) = row else { return }
            Haptics.fire(.light)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedParticipantID = row.participant.id
            }
        }
    }

    var leftOverlayColumn: some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(orderedParticipants, id: \.id) { row in
                leftOverlayCell(row)
                    .frame(height: rowHeight(for: .player(row)))
            }
        }
        .glassCardEffect(shape: RoundedRectangle(cornerRadius: layout.floatingColumnCornerRadius, style: .continuous), interactive: false)
        .opacity(showLeftOverlay ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showLeftOverlay)
    }

    // MARK: - Cells

    func headerRow(leading: String, values: [String], height: CGFloat) -> some View {
        HStack(spacing: layout.columnSpacing) {
            headerLabelCell(leading, height: height)
                .frame(width: layout.playerNameColumnWidth, alignment: .leading)

            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                headerValueCell(value, height: height)
                    .frame(width: layout.cellWidth)
            }
        }
    }

    func headerLabelCell(_ value: String, height: CGFloat) -> some View {
        Text(value.uppercased())
            .fontStyle(.poppins, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(height: height)
            .alignCenter()
            //.frame(maxWidth: .infinity, alignment: .leading)
    }

    func headerValueCell(_ value: String, height: CGFloat) -> some View {
        Text(value.uppercased())
            .fontStyle(.poppins, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(height: height)
            //.frame(maxWidth: .infinity)
    }

    func rowLabel(_ value: String, height: CGFloat) -> some View {
        Text(value.uppercased())
            .fontStyle(.poppins, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(height: height)
            //.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, layout.labelHorizontalPadding)
    }

    func playerLabel(_ row: LiveRoundViewModel.LeaderboardRow, height: CGFloat) -> some View {
        let label = row.placeLabel.replacingOccurrences(of: ".", with: "")
        let name = shortName(for: row.participant)

        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .fontStyle(.poppins, size: 9, weight: .semibold)
                .foregroundStyle(Color.neutral3)
                .lineLimit(1)

            Text(name)
                .fontStyle(.poppins, size: 12, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        //.frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, layout.labelHorizontalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.fire(.light)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedParticipantID = row.participant.id
            }
        }
    }

    func labelCell(for row: ScorecardRow) -> some View {
        let height = rowHeight(for: row)

        switch row {
        case .yards:
            return AnyView(rowLabel("Yards", height: height))
        case .handicap:
            return AnyView(rowLabel("HCP", height: height))
        case .player(let leaderboardRow):
            return AnyView(playerLabel(leaderboardRow, height: height))
        }
    }

    func leftOverlayCell(_ row: LiveRoundViewModel.LeaderboardRow) -> some View {
        let placeLabel = row.placeLabel.replacingOccurrences(of: ".", with: "")
        let initials = row.participant.name.initials

        return VStack(alignment: .leading, spacing: 2) {
            Text(placeLabel)
                .fontStyle(.poppins, size: 9, weight: .semibold)
                .foregroundStyle(Color.neutral3)
                .lineLimit(1)

            Text(initials)
                .fontStyle(.poppins, size: 12, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
        }
        //.frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, layout.labelHorizontalPadding)
    }

    func valueCell(_ value: String, color: Color) -> some View {
        Text(value)
            .fontStyle(.poppins, size: 12, weight: .semibold)
            .foregroundStyle(color)
            //.frame(maxWidth: .infinity)
    }

    func scoreCell(par: Int?, gross: Int?, net: Int?, strokesReceived: Int) -> some View {
        let displayed = viewModel.scoreBasis == .gross ? gross : net
        let isScored = gross != nil
        let value = isScored ? "\(displayed ?? 0)" : "—"
        let textColor = isScored ? palette.foregroundColor : Color.neutral4

        return VStack(spacing: 3) {
            ZStack {
                scoreDecoration(par: par, strokes: displayed)

                Text(value)
                    .fontStyle(.poppins, size: 13, weight: .semibold)
                    .foregroundStyle(textColor)
            }

            if viewModel.scoreBasis == .gross, strokesReceived > 0, isScored {
                HStack(spacing: 3) {
                    ForEach(0..<strokesReceived, id: \.self) { _ in
                        Circle()
                            .fill(palette.foregroundColor.opacity(0.7))
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        //.frame(maxWidth: .infinity, alignment: .center)
    }

    func totalScoreLabel(for participant: RoundParticipant) -> some View {
        let score = viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis)
        let label = viewModel.formattedScoreToPar(score)

        return Text(label)
            .fontStyle(.poppins, size: 13, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            //.frame(maxWidth: .infinity)
    }

    // MARK: - Decorations

    func scoreDecoration(par: Int?, strokes: Int?) -> some View {
        guard let par, let strokes else { return AnyView(EmptyView()) }
        let diff = strokes - par
        let strokeColor = Color.neutral5

        if diff <= -2 {
            return AnyView(
                Circle()
                    .fill(strokeColor)
                    .frame(width: 24, height: 24)
            )
        } else if diff == -1 {
            return AnyView(
                Circle()
                    .stroke(strokeColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
            )
        } else if diff == 1 {
            return AnyView(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(strokeColor, lineWidth: 2)
                    .frame(width: 24, height: 24)
            )
        } else if diff >= 2 {
            return AnyView(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(strokeColor)
                    .frame(width: 24, height: 24)
            )
        }

        return AnyView(EmptyView())
    }

    // MARK: - Supporting

    var scoreBasisToggle: some View {
        HStack(spacing: 10) {
            scoreBasisButton(title: "Gross", basis: .gross)
            scoreBasisButton(title: "Net", basis: .net)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCardEffect(shape: Capsule(), interactive: false)
    }

    func scoreBasisButton(title: String, basis: ScoreBasis) -> some View {
        let isSelected = viewModel.scoreBasis == basis

        return Text(title)
            .fontStyle(.poppins, size: 12, weight: .semibold)
            .foregroundStyle(isSelected ? palette.backgroundColor : palette.foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(palette.foregroundColor)
                }
            }
            .onTapGesture {
                Haptics.fire(.light)
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.scoreBasis = basis
                }
            }
    }

    func rowBackgroundColor(for row: ScorecardRow, index: Int) -> Color {
        let zebra = index.isEven ? palette.backgroundColor : Color.neutral6.opacity(0.6)

        switch row {
        case .player(let row):
            if row.participant.id == selectedParticipantID {
                let highlight = viewModel.teamColor(for: row.participant) ?? Color.accentGreen
                return highlight.opacity(0.2)
            }
            return zebra
        case .yards, .handicap:
            return zebra
        }
    }

    func shortName(for participant: RoundParticipant) -> String {
        let given = participant.name.givenName
        let family = participant.name.familyName
        guard given.isPopulated, family.isPopulated else { return participant.name.fullName }
        return "\(given) \(family.prefix(1))."
    }

    func handicapColor(_ handicap: Int) -> Color {
        let clamped = min(max(handicap, 1), 18)
        let fraction = Double(clamped - 1) / 17.0
        return Color.systemError.interpolate(to: .accentGreen, fraction: fraction)
    }

    func parLabel(for holeNumber: Int) -> String {
        guard let par = viewModel.hole(for: holeNumber)?.par else { return "—" }
        return "\(par)"
    }

    var totalParLabel: String {
        let total = displayedHoles.reduce(0) { sum, hole in
            sum + (viewModel.hole(for: hole)?.par ?? 0)
        }
        return total > 0 ? "\(total)" : "—"
    }

    var courseName: String {
        viewModel.snapshot.courseInfo?.name ?? "Scorecard"
    }
    
    var gameFormat: String {
        viewModel.snapshot.gameFormat.type.displayName
    }

    var playerCountLabel: String {
        let count = viewModel.snapshot.participants.count
        return "\(count) Player" + (count == 1 ? "" : "s")
    }

    var showLeftOverlay: Bool {
        horizontalOffset < -layout.playerNameColumnWidth * layout.leftOverlayTriggerFactor
    }

    var detailRows: [ScorecardRow] {
        var rows: [ScorecardRow] = [.yards, .handicap]
        rows.append(contentsOf: orderedParticipants.map { .player($0) })
        return rows
    }

    var headerHeight: CGFloat {
        layout.headerHoleHeight + layout.headerParHeight + layout.rowSpacing
    }

    func rowHeight(for row: ScorecardRow) -> CGFloat {
        switch row {
        case .yards, .handicap:
            return layout.metaRowHeight
        case .player:
            return layout.playerRowHeight
        }
    }
    
    enum ScorecardRow: Identifiable {
        case yards
        case handicap
        case player(LiveRoundViewModel.LeaderboardRow)

        var id: String {
            switch self {
            case .yards: return "yards"
            case .handicap: return "handicap"
            case .player(let row): return row.participant.id
            }
        }
    }

    struct GridLayout {
        let topPadding: CGFloat = 8
        let horizontalPadding: CGFloat = 16
        let sectionSpacing: CGFloat = 12
        let navSpacing: CGFloat = 16

        let gridCornerRadius: CGFloat = 18
        let floatingColumnCornerRadius: CGFloat = 12
        let headerTopPadding: CGFloat = 2
        let bottomContentPadding: CGFloat = 72
        let toggleBottomPadding: CGFloat = 16

        let columnSpacing: CGFloat = 8
        let rowSpacing: CGFloat = 8
        let cellWidth: CGFloat = 44
        let playerNameColumnWidth: CGFloat = 120
        let totalColumnWidth: CGFloat = 60
        let leftOverlayWidth: CGFloat = 60
        let leftOverlayTriggerFactor: CGFloat = 0.6
        let labelHorizontalPadding: CGFloat = 6

        let headerHoleHeight: CGFloat = 26
        let headerParHeight: CGFloat = 26
        let metaRowHeight: CGFloat = 26
        let playerRowHeight: CGFloat = 44
    }
}

// MARK: - Preview

#Preview("Full Scorecard") {
    ZStack {
        GolfTopology()
            .frame(width: UIScreen.main.bounds.width)
            .fullScreenCover(isPresented: .true) {
                FullScorecardViewPreview()
            }
    }
}

private struct FullScorecardViewPreview: View {
    @StateObject private var viewModel: LiveRoundViewModel
    private let participant: RoundParticipant

    init() {
        var snapshot = MockLiveRoundRyderCup.snapshot
        let lastHole = (snapshot.defaultTee?.holes ?? snapshot.tees.first?.holes)?.last?.number ?? 18
        let normalizedRange = HoleRange(startHole: 1, endHole: min(18, max(1, lastHole)))
        if snapshot.round.configuration.courses.isEmpty {
            let fallbackInfo = snapshot.courseInfo ?? CourseInfo(course: .init(), for: .full18)
            snapshot.round.configuration.courses = [
                CourseSegment(courseInfo: fallbackInfo, holeRange: normalizedRange, defaultTee: snapshot.defaultTee?.id)
            ]
        } else {
            var segment = snapshot.round.configuration.courses[0]
            segment.holeRange = normalizedRange
            snapshot.round.configuration.courses[0] = segment
        }
        snapshot.scoring = Self.makePreviewScores(snapshot: snapshot)
        let appSession = AppSession()
        appSession.ephemeralParticipantID = snapshot.participants.first?.id

        let roundSession = RoundSession()
        roundSession.snapshot = snapshot

        let vm = LiveRoundViewModel()
        vm.bind(appSession: appSession, roundSession: roundSession)
        vm.set(snapshot: snapshot)
        vm.selectedTeeID = snapshot.defaultTee?.id

        _viewModel = StateObject(wrappedValue: vm)
        participant = snapshot.participants.first!
    }

    var body: some View {
        FullScorecardView(viewModel: viewModel, participant: participant)
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
