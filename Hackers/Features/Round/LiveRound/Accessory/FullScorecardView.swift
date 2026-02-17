//
//  FullScorecardView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/9/26.
//

import SwiftUI

private extension View {
    func glassCardOverlay() -> some View {
        self.glassCardEffect(
            cornerRadius: 0,
            interactive: false,
            forceMaterial: true,
            strokeOpacity: 0,
            shadowOpacity: 0
        )
    }
}

struct FullScorecardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant

    @State private var selectedParticipantID: String?
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var previousVerticalOffset: CGFloat = 0
    @State private var scrollDirection: Int = 0
    @State private var directionalScrollDistance: CGFloat = 0
    @State private var isFloatingToolbarVisible = true
    @State private var isUserDraggingVertically = false
    @State private var isRotated = false
    @State private var isGolfBallToggleSelected = true
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
                        .padding(.horizontal, layout.horizontalPadding)

                    scorecardGrid(in: layoutSize)
                        .overlay(alignment: .bottom) {
                            floatingToolbar
                                .opacity(isFloatingToolbarVisible ? 1 : 0)
                                .offset(y: isFloatingToolbarVisible ? 0 : layout.toolbarHiddenOffset)
                                .allowsHitTesting(isFloatingToolbarVisible)
                                .padding(.bottom, isRotated ? layout.rotatedToolbarBottomPadding : 0)
                        }
                }
                .padding(.top, layout.topPadding)
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
            previousVerticalOffset = verticalOffset
        }
        .onChange(of: verticalOffset) { _, newValue in
            handleVerticalScrollChange(newValue)
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
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 8) {
                    Text(gameFormat)
                    
                    Dot()
                    
                    Text(playerCountLabel)
                }
                .fontStyle(kFontName, size: 11, weight: .medium)
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
        let gridWidth = size.width
        let cellWidth = adaptiveCellWidth(for: gridWidth)

        return ZStack(alignment: .topLeading) {
            ObservableScrollView(offset: $verticalOffset, axes: .vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: stickyTopSectionHeight)

                    ZStack(alignment: .topLeading) {
                        mainHorizontalScroll(width: gridWidth, cellWidth: cellWidth)

                        if showLeftOverlay {
                            leftOverlayColumn
                                .frame(width: layout.leftOverlayWidth)
                                .alignLeading()
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                }
                .padding(.bottom, layout.bottomScrollPadding + (isRotated ? layout.rotatedBottomScrollPadding : 0))
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { _ in
                        isUserDraggingVertically = true
                    }
                    .onEnded { _ in
                        isUserDraggingVertically = false
                        directionalScrollDistance = 0
                        scrollDirection = 0
                        revealToolbarIfAtTop(verticalOffset)
                    }
            )

            headerOverlay(width: gridWidth, cellWidth: cellWidth)
        }
        .background(palette.backgroundColor)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Header Overlay

    @ViewBuilder
    func headerOverlay(width: CGFloat, cellWidth: CGFloat) -> some View {
        let middleViewportWidth = width

        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                stickyLeadingLabels
                    .frame(width: layout.playerNameColumnWidth, alignment: .leading)

                stickyHoleValues(cellWidth: cellWidth)
            }
            .offset(x: horizontalOffset)
            .frame(width: middleViewportWidth, alignment: .leading)
            .clipped()

            if showLeftOverlay {
                stickyLeftOverlayLabels
                    .frame(width: layout.leftOverlayWidth, alignment: .leading)
                    .glassCardOverlay()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: width, height: stickyTopSectionHeight, alignment: .topLeading)
        .frame(height: stickyTopSectionHeight, alignment: .top)
        .padding(.top, layout.headerTopPadding)
        .glassCardOverlay()
    }

    var stickyLeadingLabels: some View {
        VStack(spacing: layout.rowSpacing) {
            stickyLabelCell("Hole", height: layout.headerHoleHeight)
            stickyLabelCell("Par", height: layout.headerParHeight)
            if isGolfBallToggleSelected {
                stickyLabelCell("Yards", height: layout.metaRowHeight)
                stickyLabelCell("HCP", height: layout.metaRowHeight)
            }
        }
    }

    func stickyHoleValues(cellWidth: CGFloat) -> some View {
        VStack(spacing: layout.rowSpacing) {
            stickyValueRow(values: holeHeaderValues, height: layout.headerHoleHeight, cellWidth: cellWidth)
            stickyValueRow(values: parHeaderValues, height: layout.headerParHeight, cellWidth: cellWidth)
            if isGolfBallToggleSelected {
                stickyValueRow(values: yardageHeaderValues, height: layout.metaRowHeight, cellWidth: cellWidth)
                stickyValueRow(values: handicapHeaderValues, height: layout.metaRowHeight, cellWidth: cellWidth)
            }
        }
    }

    func mainHorizontalScroll(width: CGFloat, cellWidth: CGFloat) -> some View {
        ObservableScrollView(offset: $horizontalOffset, axes: .horizontal, showsIndicators: false) {
            VStack(spacing: layout.rowSpacing) {
                ForEach(Array(detailRows.enumerated()), id: \.offset) { index, row in
                    detailRow(row: row, index: index, cellWidth: cellWidth)
                    .frame(height: rowHeight(for: row), alignment: .center)
                }
            }
        }
        .frame(width: width)
        .clipped()
    }

    func detailRow(row: ScorecardRow, index: Int, cellWidth: CGFloat) -> some View {
        let background = rowBackgroundColor(for: row, index: index)

        return HStack(spacing: layout.columnSpacing) {
            labelCell(for: row)
                .frame(width: layout.playerNameColumnWidth)
                .frame(maxHeight: .infinity, alignment: .center)

            ForEach(Array(scorecardColumns.enumerated()), id: \.offset) { _, column in
                detailColumnCell(row: row, column: column)
                    .frame(width: cellWidth)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            
            Color.clear
                .frame(width: layout.trailingScrollPadding)
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
        case .player(let row):
            let gross = viewModel.grossStrokes(for: row.participant.id, holeNumber: holeNumber)
            let net = viewModel.netStrokesOnHole(participant: row.participant, holeNumber: holeNumber)
            let strokesReceived = viewModel.strokesReceivedOnHole(participant: row.participant, holeNumber: holeNumber)
            let par = viewModel.hole(for: holeNumber)?.par
            let isSelected = row.participant.id == selectedParticipantID
            let accentColor = participantHighlightColor(for: row.participant)

            return AnyView(
                scoreCell(
                    par: par,
                    gross: gross,
                    net: net,
                    strokesReceived: strokesReceived,
                    isSelected: isSelected,
                    highlightColor: accentColor
                )
            )
        }
    }

    func detailColumnCell(row: ScorecardRow, column: ScorecardColumn) -> some View {
        switch row {
        case .player(let leaderboardRow):
            switch column {
            case .hole(let holeNumber):
                return AnyView(detailCell(row: row, holeNumber: holeNumber))
            case .out(let holes), .inSegment(let holes):
                return AnyView(segmentSummaryCell(participant: leaderboardRow.participant, holes: holes))
            case .total:
                return AnyView(totalScoreLabel(for: leaderboardRow.participant))
            }
        }
    }

    func segmentSummaryCell(participant: RoundParticipant, holes: [Int]) -> some View {
        let summary = segmentScoreSummary(for: participant, holes: holes)

        return VStack(spacing: 2) {
            Text(summary.primary)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)

            Text(summary.secondary)
                .fontStyle(kFontName, size: 9, weight: .medium)
                .foregroundStyle(Color.neutral3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, layout.cellHorizontalPadding)
        .padding(.vertical, layout.cellVerticalPadding)
    }

    var leftOverlayColumn: some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(Array(orderedParticipants.enumerated()), id: \.element.id) { index, row in
                leftOverlayCell(row)
                    .frame(height: rowHeight(for: .player(row)), alignment: .center)
            }
        }
        .glassCardOverlay()
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
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
            .frame(height: height)
    }

    func headerValueCell(_ value: String, height: CGFloat) -> some View {
        Text(value.uppercased())
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
            .frame(height: height)
    }

    func stickyLabelCell(_ value: String, height: CGFloat) -> some View {
        rowLabel(value, height: height)
    }

    var stickyLeftOverlayLabels: some View {
        VStack(spacing: layout.rowSpacing) {
            stickyCompactLabelCell("Hole", height: layout.headerHoleHeight)
            stickyCompactLabelCell("Par", height: layout.headerParHeight)
            if isGolfBallToggleSelected {
                stickyCompactLabelCell("Yards", height: layout.metaRowHeight)
                stickyCompactLabelCell("HCP", height: layout.metaRowHeight)
            }
        }
    }

    func stickyValueRow(values: [StickyValue], height: CGFloat, cellWidth: CGFloat) -> some View {
        HStack(spacing: layout.columnSpacing) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                stickyValueCell(value, height: height)
                    .frame(width: cellWidth)
            }
            
            Color.clear
                .frame(width: layout.trailingScrollPadding)
        }
    }

    func stickyValueCell(_ value: StickyValue, height: CGFloat) -> some View {
        Text(value.text)
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(value.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
            .frame(height: height)
    }

    func stickyCompactLabelCell(_ value: String, height: CGFloat) -> some View {
        Text(value.uppercased())
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, layout.compactOverlayLeadingPadding)
            .padding(.trailing, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
            .frame(height: height)
    }

    func rowLabel(_ value: String, height: CGFloat) -> some View {
        Text(value.uppercased())
            .fontStyle(kFontName, size: 11, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, layout.labelHorizontalPadding)
            .padding(.trailing, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
            .frame(height: height)
    }

    func playerLabel(_ row: LiveRoundViewModel.LeaderboardRow) -> some View {
        let label = row.placeLabel.replacingOccurrences(of: ".", with: "")
        let name = shortName(for: row.participant)
        let isSelected = row.participant.id == selectedParticipantID
        let placeColor = isSelected ? participantHighlightColor(for: row.participant) : Color.neutral3
        let accrued = accruedScoreLabel(for: row.participant)
        let accruedColor = isSelected ? participantHighlightColor(for: row.participant) : palette.foregroundColor

        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 8) {
//                Text(label)
//                    .fontStyle(kFontName, size: 9, weight: .semibold)
//                    .foregroundStyle(placeColor)
//                    .lineLimit(1)
//                    .padding(.top, 6)
                
                Text(accrued)
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(accruedColor)
                    .lineLimit(1)
            }

            Text(name)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

//            Text(label)
//                .fontStyle(kFontName, size: 9, weight: .semibold)
//                .foregroundStyle(placeColor)
//                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, layout.labelHorizontalPadding)
        .padding(.trailing, layout.cellHorizontalPadding)
        .padding(.vertical, layout.cellVerticalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.fire(.light)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedParticipantID = row.participant.id
            }
        }
    }

    func labelCell(for row: ScorecardRow) -> some View {
        switch row {
        case .player(let leaderboardRow):
            return AnyView(playerLabel(leaderboardRow))
        }
    }

    func leftOverlayCell(_ row: LiveRoundViewModel.LeaderboardRow) -> some View {
        let placeLabel = row.placeLabel.replacingOccurrences(of: ".", with: "")
        let initials = row.participant.name.initials
        let isSelected = row.participant.id == selectedParticipantID
        let placeColor = isSelected ? participantHighlightColor(for: row.participant) : Color.neutral3
        let accrued = accruedScoreLabel(for: row.participant)
        let accruedColor = isSelected ? participantHighlightColor(for: row.participant) : palette.foregroundColor

        return VStack(alignment: .leading, spacing: 1) {
            Text(accrued)
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(accruedColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(initials)
                .fontStyle(kFontName, size: 12, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)

//            Text(placeLabel)
//                .fontStyle(kFontName, size: 9, weight: .semibold)
//                .foregroundStyle(placeColor)
//                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, layout.labelHorizontalPadding)
        .padding(.trailing, layout.cellHorizontalPadding)
        .padding(.vertical, layout.cellVerticalPadding)
        .alignLeading()
    }

    func valueCell(_ value: String, color: Color) -> some View {
        Text(value)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
    }

    func scoreCell(
        par: Int?,
        gross: Int?,
        net: Int?,
        strokesReceived: Int,
        isSelected: Bool,
        highlightColor: Color
    ) -> some View {
        let displayed = viewModel.scoreBasis == .gross ? gross : net
        let isScored = gross != nil
        let value = isScored ? "\(displayed ?? 0)" : "—"
        let baseTextColor = isScored ? palette.foregroundColor : Color.neutral4
        let textColor = isSelected && !isScored ? highlightColor : baseTextColor

        return VStack(spacing: 8) {
            ZStack {
                scoreDecoration(par: par, strokes: displayed, color: isSelected ? highlightColor : Color.neutral5)

                Text(value)
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(textColor)
            }

            if viewModel.scoreBasis == .gross {
                if strokesReceived > 0, isScored {
                    HStack(spacing: 3) {
                        ForEach(0..<strokesReceived, id: \.self) { _ in
                            Circle()
                                .fill((palette.foregroundColor).opacity(0.7))
                                .frame(width: 3, height: 3)
                        }
                    }
                } else {
                    // Invisible circle to persist equal horizontal alignment
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 3, height: 3)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, layout.cellHorizontalPadding)
        .padding(.vertical, layout.cellVerticalPadding)
    }

    func totalScoreLabel(for participant: RoundParticipant) -> some View {
        let score = viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis)
        let label = scoreToParLabel(score)

        return Text(label)
            .fontStyle(kFontName, size: 17, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
    }

    // MARK: - Decorations

    func scoreDecoration(par: Int?, strokes: Int?, color: Color) -> some View {
        guard let par, let strokes else { return AnyView(EmptyView()) }
        let diff = strokes - par
        let strokeColor = color

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

    var floatingToolbar: some View {
        HStack(spacing: 10) {
            if viewModel.handicapsEnabled {
                scoreBasisButton(title: "Gross", basis: .gross)
                scoreBasisButton(title: "Net", basis: .net)
                
                Rectangle()
                    .fill(Color.neutral4.opacity(0.7))
                    .frame(width: 1, height: 16)
            }
            
            golfBallButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCardEffect(shape: Capsule(), interactive: false)
    }

    func scoreBasisButton(title: String, basis: ScoreBasis) -> some View {
        let isSelected = viewModel.scoreBasis == basis

        return Text(title)
            .fontStyle(kFontName, size: 12, weight: .semibold)
            .foregroundStyle(isSelected ? palette.backgroundColor : palette.foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                isSelected ? palette.foregroundColor : Color.systemClear
            }
            .clipShape(Capsule())
            .onTapGesture {
                Haptics.fire(.light)
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.scoreBasis = basis
                }
            }
    }

    var golfBallButton: some View {
        Icon(name: "f450", size: 12, weight: .regular)
            .foregroundStyle(isGolfBallToggleSelected ? palette.backgroundColor : palette.foregroundColor)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background {
                isGolfBallToggleSelected ? palette.foregroundColor : Color.systemClear
            }
            .clipShape(Circle())
            .onTapGesture {
                Haptics.fire(.light)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGolfBallToggleSelected.toggle()
                }
            }
    }

    func rowBackgroundColor(for row: ScorecardRow, index: Int) -> Color {
        let zebra = index.isEven ? palette.backgroundColor : Color.neutral6.opacity(0.6)

        switch row {
        case .player(let row):
            if row.participant.id == selectedParticipantID {
                let highlight = participantHighlightColor(for: row.participant)
                return highlight.opacity(0.125)
            }
            return zebra
        }
    }

    func handleVerticalScrollChange(_ newValue: CGFloat) {
        let delta = newValue - previousVerticalOffset
        previousVerticalOffset = newValue

        if revealToolbarIfAtTop(newValue) {
            return
        }

        guard abs(delta) > 0.5 else { return }

        let nextDirection = delta < 0 ? -1 : 1
        if nextDirection != scrollDirection {
            scrollDirection = nextDirection
            directionalScrollDistance = 0
        }

        directionalScrollDistance += abs(delta)

        if scrollDirection < 0,
           isFloatingToolbarVisible,
           directionalScrollDistance >= layout.toolbarHideThreshold {
            withAnimation(.easeInOut(duration: 0.18)) {
                isFloatingToolbarVisible = false
            }
            directionalScrollDistance = 0
        } else if scrollDirection > 0,
                  isUserDraggingVertically,
                  !isFloatingToolbarVisible,
                  directionalScrollDistance >= (isRotated ? layout.rotatedToolbarShowThreshold : layout.toolbarShowThreshold) {
            withAnimation(.easeInOut(duration: 0.12)) {
                isFloatingToolbarVisible = true
            }
            directionalScrollDistance = 0
        }
    }

    @discardableResult
    func revealToolbarIfAtTop(_ offset: CGFloat) -> Bool {
        guard offset >= -layout.toolbarTopRevealTolerance else { return false }
        directionalScrollDistance = 0
        scrollDirection = 0
        guard !isFloatingToolbarVisible else { return true }
        withAnimation(.easeInOut(duration: 0.18)) {
            isFloatingToolbarVisible = true
        }
        return true
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

    func handicapColor(for holeNumber: Int) -> Color {
        guard let handicap = viewModel.hole(for: holeNumber)?.handicap else { return Color.neutral4 }
        return handicapColor(handicap)
    }

    func yardageLabel(for holeNumber: Int) -> String {
        let yardage = viewModel.hole(for: holeNumber)?.yardage
        return yardage.map(String.init) ?? "—"
    }

    func handicapLabel(for holeNumber: Int) -> String {
        let value = viewModel.hole(for: holeNumber)?.handicap
        return value.map(String.init) ?? "—"
    }

    func participantHighlightColor(for participant: RoundParticipant) -> Color {
        let c = viewModel.teamColor(for: participant) ?? Color.accentGreen
        return c.opacity(0.8)
    }

    func parLabel(for holeNumber: Int) -> String {
        guard let par = viewModel.hole(for: holeNumber)?.par else { return "—" }
        return "\(par)"
    }

    func totalYardsLabel(for holes: [Int]) -> String {
        let total = holes.reduce(0) { sum, hole in
            sum + (viewModel.hole(for: hole)?.yardage ?? 0)
        }
        return total > 0 ? "\(total)" : "—"
    }

    func segmentScoreSummary(for participant: RoundParticipant, holes: [Int]) -> (primary: String, secondary: String) {
        let segmentScores = holes.compactMap { holeNumber -> (strokes: Int, par: Int)? in
            guard let par = viewModel.hole(for: holeNumber)?.par else { return nil }
            guard let gross = viewModel.grossStrokes(for: participant.id, holeNumber: holeNumber) else { return nil }
            let net = viewModel.netStrokesOnHole(participant: participant, holeNumber: holeNumber)
            let displayed = viewModel.scoreBasis == .gross ? gross : (net ?? gross)
            return (displayed, par)
        }

        guard !segmentScores.isEmpty else { return ("—", "") }

        let totalStrokes = segmentScores.reduce(0) { $0 + $1.strokes }
        let totalPar = segmentScores.reduce(0) { $0 + $1.par }
        return (scoreToParLabel(totalStrokes - totalPar), "\(totalStrokes)")
    }

    func accruedScoreLabel(for participant: RoundParticipant) -> String {
        let score = viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis)
        return scoreToParLabel(score)
    }

    func scoreToParLabel(_ score: Int) -> String {
        if score == 0 { return "E" }
        if score > 0 { return "+\(score)" }
        return "\(score)"
    }

    var scorecardColumns: [ScorecardColumn] {
        if displayedHoles.count <= 9 {
            return displayedHoles.map { .hole($0) } + [.total]
        }

        let front = firstSegmentHoles
        let back = secondSegmentHoles

        return front.map { .hole($0) }
            + [.out(front)]
            + back.map { .hole($0) }
            + [.inSegment(back), .total]
    }

    var firstSegmentHoles: [Int] {
        Array(displayedHoles.prefix(min(9, displayedHoles.count)))
    }

    var secondSegmentHoles: [Int] {
        guard displayedHoles.count > 9 else { return [] }
        return Array(displayedHoles.dropFirst(9))
    }

    var holeHeaderValues: [StickyValue] {
        scorecardColumns.map { column in
            switch column {
            case .hole(let holeNumber):
                return .init(text: "\(holeNumber)", color: palette.foregroundColor)
            case .out:
                return .init(text: "OUT", color: palette.foregroundColor)
            case .inSegment:
                return .init(text: "IN", color: palette.foregroundColor)
            case .total:
                return .init(text: "TOT", color: palette.foregroundColor)
            }
        }
    }

    var parHeaderValues: [StickyValue] {
        scorecardColumns.map { column in
            switch column {
            case .hole(let holeNumber):
                return .init(text: parLabel(for: holeNumber), color: palette.foregroundColor)
            case .out(let holes), .inSegment(let holes):
                return .init(text: parTotalLabel(for: holes), color: palette.foregroundColor)
            case .total:
                return .init(text: totalParLabel, color: palette.foregroundColor)
            }
        }
    }

    var yardageHeaderValues: [StickyValue] {
        scorecardColumns.map { column in
            switch column {
            case .hole(let holeNumber):
                return .init(text: yardageLabel(for: holeNumber), color: palette.foregroundColor)
            case .out(let holes), .inSegment(let holes):
                return .init(text: totalYardsLabel(for: holes), color: palette.foregroundColor)
            case .total:
                return .init(text: totalYardsLabel, color: palette.foregroundColor)
            }
        }
    }

    var handicapHeaderValues: [StickyValue] {
        scorecardColumns.map { column in
            switch column {
            case .hole(let holeNumber):
                return .init(text: handicapLabel(for: holeNumber), color: handicapColor(for: holeNumber))
            case .out, .inSegment, .total:
                return .init(text: "", color: palette.foregroundColor)
            }
        }
    }

    var totalParLabel: String {
        let total = displayedHoles.reduce(0) { sum, hole in
            sum + (viewModel.hole(for: hole)?.par ?? 0)
        }
        return total > 0 ? "\(total)" : "—"
    }

    var totalYardsLabel: String {
        totalYardsLabel(for: displayedHoles)
    }

    func parTotalLabel(for holes: [Int]) -> String {
        let total = holes.reduce(0) { sum, hole in
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
        orderedParticipants.map { .player($0) }
    }

    func adaptiveCellWidth(for availableWidth: CGFloat) -> CGFloat {
        let columnCount = max(scorecardColumns.count, 1)
        let baselineContentWidth = layout.playerNameColumnWidth
            + (CGFloat(columnCount) * layout.cellWidth)
            + layout.trailingScrollPadding
        guard baselineContentWidth < availableWidth else { return layout.cellWidth }

        let expandableWidth = availableWidth - layout.playerNameColumnWidth - layout.trailingScrollPadding
        guard expandableWidth > 0 else { return layout.cellWidth }

        return max(layout.cellWidth, expandableWidth / CGFloat(columnCount))
    }

    var stickyTopSectionHeight: CGFloat {
        let base = layout.headerHoleHeight + layout.headerParHeight + layout.rowSpacing
        let meta = (layout.metaRowHeight * 2) + layout.rowSpacing
        return base + (isGolfBallToggleSelected ? meta : 0)
    }

    func rowHeight(for row: ScorecardRow) -> CGFloat {
        switch row {
        case .player:
            return layout.playerRowHeight
        }
    }
    
    enum ScorecardRow: Identifiable {
        case player(LiveRoundViewModel.LeaderboardRow)

        var id: String {
            switch self {
            case .player(let row): return row.participant.id
            }
        }
    }

    enum ScorecardColumn {
        case hole(Int)
        case out([Int])
        case inSegment([Int])
        case total
    }

    struct StickyValue {
        let text: String
        let color: Color
    }

    struct GridLayout {
        let topPadding: CGFloat = 8
        let horizontalPadding: CGFloat = 16
        let sectionSpacing: CGFloat = 12
        let navSpacing: CGFloat = 16

        let gridCornerRadius: CGFloat = 18
        let floatingColumnCornerRadius: CGFloat = 12
        let headerTopPadding: CGFloat = 2

        let columnSpacing: CGFloat = 0
        let rowSpacing: CGFloat = 0
        let cellWidth: CGFloat = 44
        let playerNameColumnWidth: CGFloat = 120
        let leftOverlayWidth: CGFloat = 60
        let leftOverlayTriggerFactor: CGFloat = 0.6
        let cellHorizontalPadding: CGFloat = 8
        let cellVerticalPadding: CGFloat = 4
        let labelHorizontalPadding: CGFloat = 16
        let compactOverlayLeadingPadding: CGFloat = 10
        let trailingScrollPadding: CGFloat = 12
        let toolbarHideThreshold: CGFloat = 10
        let toolbarShowThreshold: CGFloat = 60
        let rotatedToolbarShowThreshold: CGFloat = 30
        let toolbarTopRevealTolerance: CGFloat = 4
        let toolbarHiddenOffset: CGFloat = 16
        let rotatedToolbarBottomPadding: CGFloat = 16
        let bottomScrollPadding: CGFloat = 52
        let rotatedBottomScrollPadding: CGFloat = 44

        let headerHoleHeight: CGFloat = 26
        let headerParHeight: CGFloat = 26
        let metaRowHeight: CGFloat = 26
        let playerRowHeight: CGFloat = 56
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
