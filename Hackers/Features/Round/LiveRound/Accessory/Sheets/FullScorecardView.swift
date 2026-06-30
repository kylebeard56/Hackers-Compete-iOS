//
//  FullScorecardView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/9/26.
//

import SwiftUI

private extension View {
    func glassCardOverlay(cornerRadius: CGFloat = 0, tint: Color? = nil) -> some View {
        self.glassCardEffect(
            cornerRadius: cornerRadius,
            interactive: false,
            forceMaterial: true,
            tint: tint,
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
    var allowsScoreEditing: Bool = true
    var initialSelectedScoringUnitID: String? = nil
    
    @State private var selectedParticipantID: String?
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var previousVerticalOffset: CGFloat = 0
    @State private var scrollDirection: Int = 0
    @State private var directionalScrollDistance: CGFloat = 0
    @State private var isFloatingToolbarVisible = true
    @State private var isUserDraggingVertically = false
    @State private var isRotated = false
    @State private var showPar = true
    @State private var showYardage = true
    @State private var showHandicap = true
    @State private var scoreEditAnchor: ScoreEditAnchor?
    @State private var scoreEditCustomText: String = ""
    @State private var scoreEditShowCustomPrompt = false
    @State private var showScorecardVisibilitySheet = false
    @State private var editVisibilityPage: Int? = 0  // 0 = toggles, 1 = players
    @State private var rightPanelContent: RightPanelContent? = nil
    private let layout = GridLayout()
    
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var effectiveAccent: Color {
        viewModel.theme.color
    }
    
    private var displayedHoles: [Int] {
        viewModel.courseOrderHoleNumbers
    }
    
    private var orderedParticipants: [LiveRoundViewModel.LeaderboardRow] {
        viewModel.scorecardParticipants
    }
    
    var kHeaderTextColor: Color { palette.backgroundColor }
    
    // MARK: - Main Body ✅
    
    var body: some View {
        GeometryReader { geom in
            let layoutSize = isRotated
                ? CGSize(width: max(1, geom.size.height), height: max(1, geom.size.width))
                : CGSize(width: max(1, geom.size.width), height: max(1, geom.size.height))
            
            ZStack {
                VStack(spacing: layout.sectionSpacing) {
                    topBar
                    
                    Group {
                        if isRotated {
                            HStack(spacing: 0) {
                                
                                scorecardGrid(in: CGSize(
                                    width: max(1, (rightPanelContent != nil ? layoutSize.width - layout.rightPanelWidth : layoutSize.width) - layout.gridMargin * 2),
                                    height: max(1, layoutSize.height - layout.gridMargin * 2)
                                ))
                                //                                .overlay(alignment: .bottom) {
                                //                                    toolbarOverlay
                                //                                }
                                
                                if let content = rightPanelContent {
                                    rightPanelView(content: content)
                                    //.frame(height: layoutSize.height - layout.gridMargin * 2)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                            }
                            .animation(.easeInOut(duration: 0.25), value: rightPanelContent != nil)
                            
                            //toolbarFooter
                        } else {
                            scorecardGrid(in: CGSize(
                                width: max(1, layoutSize.width - layout.gridMargin * 2),
                                height: max(1, layoutSize.height - layout.gridMargin * 2)
                            ))
                            //                                .overlay(alignment: .bottom) {
                            //                                    toolbarOverlay
                            //                                }
                            
                            toolbarFooter
                        }
                    }
                }
                .padding(.top, layout.topPadding)
            }
            //.padding(layout.screenEdgePadding)
            .rotationEffect(.degrees(isRotated ? 90 : 0))
            .frame(
                width: max(1, layoutSize.width - layout.horizontalPadding * 2),
                height: max(1, layoutSize.height - layout.horizontalPadding * 2)
            )
            .position(x: geom.size.width / 2, y: geom.size.height / 2)
            .animation(.easeInOut(duration: 0.25), value: isRotated)
        }
        .background(viewModel.theme.color.opacity(0.1)) // Add a tad more color
        .onAppear {
            viewModel.set(snapshot: viewModel.snapshot)
            if selectedParticipantID == nil {
                selectedParticipantID = initialSelectedScoringUnitID ?? participant.id
            }
            previousVerticalOffset = verticalOffset
        }
        .onChange(of: verticalOffset) { _, newValue in
            handleVerticalScrollChange(newValue)
        }
        .sheet(isPresented: $showScorecardVisibilitySheet) {
            ScorecardVisibilitySheet(viewModel: viewModel, onDismiss: { showScorecardVisibilitySheet = false })
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        .alert("Enter score", isPresented: $scoreEditShowCustomPrompt) {
            TextField("Strokes", text: $scoreEditCustomText)
                .keyboardType(.numberPad)
            Button("Save") {
                Task { await submitScoreEditCustom() }
            }
            Button("Cancel", role: .cancel) {
                scoreEditAnchor = nil
                scoreEditCustomText = ""
                rightPanelContent = nil
            }
        } message: {
            Text("Enter the gross strokes for this hole.")
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
                .foregroundStyle(Color.neutral)
            }
            
            Spacer(minLength: 0)
            
            if isRotated {
                if viewModel.handicapsEnabled {
                    grossNetPicker
                }
                
                filterMenuButton
            }

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
        let gridWidth = max(1, size.width)
        let cellWidth = adaptiveCellWidth(for: gridWidth)
        
        return ZStack(alignment: .topLeading) {
            ObservableScrollView(offset: $verticalOffset, axes: .vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    mainHorizontalScroll(width: gridWidth, cellWidth: cellWidth)
                    
                    if showLeftOverlay {
                        leftOverlayColumn
                            .frame(width: layout.leftOverlayWidth)
                            .padding(.top, stickyTopSectionHeight)
                            .alignLeading()
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                //.padding(.bottom, layout.bottomScrollPadding + (isRotated ? layout.rotatedBottomScrollPadding : 0))
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
                .allowsHitTesting(false)
        }
        //.padding(layout.gridMargin)
        .glassCardEffect(
            cornerRadius: layout.gridCornerRadius,
            interactive: false,
            strokeOpacity: 0,
            shadowOpacity: 0
        )
        //.ignoresSafeArea(edges: .bottom)
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
                    .glassCardEffect(
                        cornerRadius: 0,
                        material: .bar,
                        interactive: false,
                        forceMaterial: true,
                        tint: nil,
                        strokeOpacity: 0,
                        shadowOpacity: 0
                    )
                //.glassCardOverlay(cornerRadius: layout.stickyHeaderCornerRadius)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: width, height: stickyTopSectionHeight, alignment: .topLeading)
        .frame(height: stickyTopSectionHeight, alignment: .top)
        //.padding(.top, layout.headerTopPadding)
        .foregroundStyle(palette.backgroundColor)
        //.glassCardEffect(cornerRadius: 0, tint: viewModel.theme.color.opacity(0.6), strokeOpacity: 0, shadowOpacity: 0)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(viewModel.theme.color).opacity(viewModel.theme.scorecardOpacity)
            }
        }
        //.glassCardOverlay(cornerRadius: layout.stickyHeaderCornerRadius)
    }
    
    var stickyLeadingLabels: some View {
        VStack(spacing: layout.rowSpacing) {
            stickyLabelCell("Hole", height: layout.headerHoleHeight)
            if showPar {
                stickyLabelCell("Par", height: layout.headerParHeight)
            }
            if showYardage {
                stickyLabelCell("Yards", height: layout.metaRowHeight)
            }
            if showHandicap {
                stickyLabelCell("HCP", height: layout.metaRowHeight)
            }
        }
    }
    
    func stickyHoleValues(cellWidth: CGFloat) -> some View {
        VStack(spacing: layout.rowSpacing) {
            stickyValueRow(values: holeHeaderValues, height: layout.headerHoleHeight, cellWidth: cellWidth)
            if showPar {
                stickyValueRow(values: parHeaderValues, height: layout.headerParHeight, cellWidth: cellWidth)
            }
            if showYardage {
                stickyValueRow(values: yardageHeaderValues, height: layout.metaRowHeight, cellWidth: cellWidth)
            }
            if showHandicap {
                stickyValueRow(values: handicapHeaderValues, height: layout.metaRowHeight, cellWidth: cellWidth)
            }
        }
    }
    
    func mainHorizontalScroll(width: CGFloat, cellWidth: CGFloat) -> some View {
        ObservableScrollView(offset: $horizontalOffset, axes: .horizontal, showsIndicators: false) {
            VStack(spacing: layout.rowSpacing) {
                Color.clear
                    .frame(height: stickyTopSectionHeight)
                
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
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture {
            guard case .player(let row) = row else { return }
            Haptics.fire(.light)
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedParticipantID.toggle(to: row.id)
                if isRotated { rightPanelContent = nil }
            }
        }
    }
    
    func detailCell(row: ScorecardRow, holeNumber: Int) -> some View {
        switch row {
        case .player(let row):
            let gross = grossStrokes(for: row, holeNumber: holeNumber)
            let net = netStrokes(for: row, holeNumber: holeNumber)
            let strokesReceived = strokesReceived(for: row, holeNumber: holeNumber)
            let par = viewModel.hole(for: holeNumber)?.par ?? 4
            let isSelected = row.id == selectedParticipantID
            let highlightStyle = participantHighlightStyle(for: row.participant)
            let accentColor = highlightStyle.accent.opacity(0.8)
            let canEditParticipant = allowsScoreEditing && viewModel.canEditScorecard(participant: row.participant)
            let scoreCellView = scoreCell(
                par: par,
                gross: gross,
                net: net,
                strokesReceived: strokesReceived,
                isSelected: isSelected,
                highlightColor: accentColor,
                highlightTextColor: highlightStyle.readableText
            )
            let isEditing: Bool
            if case .scoreEdit(let anchor) = rightPanelContent, isRotated {
                isEditing = anchor.scoringUnitID == row.scoringUnitID && anchor.holeNumber == holeNumber
            } else {
                isEditing = false
            }
            
            if canEditParticipant {
                if isRotated {
                    return AnyView(
                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedParticipantID = row.id
                                rightPanelContent = .scoreEdit(ScoreEditAnchor(row: row, holeNumber: holeNumber))
                            }
                        } label: {
                            scoreCellView
                                .background(
                                    isEditing ? accentColor.opacity(0.2) : Color.clear
                                )
                                .animation(.easeInOut(duration: 0.2), value: rightPanelContent)
                        }
                            .buttonStyle(.plain)
                    )
                } else {
                    return AnyView(
                        Menu {
                            scoreEditMenuContent(row: row, holeNumber: holeNumber, par: par, currentGross: gross)
                        } label: {
                            scoreCellView
                        }
                            .menuStyle(.borderlessButton)
                    )
                }
            } else {
                return AnyView(scoreCellView)
            }
        }
    }
    
    @ViewBuilder
    func scoreEditMenuContent(
        row: LiveRoundViewModel.LeaderboardRow,
        holeNumber: Int, par: Int,
        currentGross: Int?
    ) -> some View {
        let currentValue = scoreInputValue(for: row, holeNumber: holeNumber)
        let (primary, more) = viewModel.scoreMenuOptions(for: holeNumber)
        
        Section(header: Text(viewModel.isFriendlyScoreInputMode ? "Enter score relative to par" : "Enter gross score")) {
            ForEach(primary, id: \.self) { strokes in
                Button {
                    Haptics.fire(.light)
                    Task {
                        if currentValue == strokes {
                            await viewModel.clearScore(scoringUnitID: row.scoringUnitID, participant: row.participant, holeNumber: holeNumber)
                        } else {
                            await viewModel.setScoreInputValue(scoringUnitID: row.scoringUnitID, participant: row.participant, holeNumber: holeNumber, value: strokes)
                        }
                    }
                } label: {
                    HStack {
                        Text(menuScoreLabel(value: strokes, par: par))
                            .foregroundStyle(currentValue == strokes ? effectiveAccent : palette.foregroundColor)
                        Spacer(minLength: 0)
                        if currentValue == strokes {
                            Icon(name: "checkmark", size: 16, weight: .semibold)
                                .foregroundStyle(effectiveAccent)
                        }
                    }
                }
            }
        }
        
        if !more.isEmpty {
            Menu("More") {
                ForEach(more, id: \.self) { strokes in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            if currentValue == strokes {
                                await viewModel.clearScore(scoringUnitID: row.scoringUnitID, participant: row.participant, holeNumber: holeNumber)
                            } else {
                                await viewModel.setScoreInputValue(scoringUnitID: row.scoringUnitID, participant: row.participant, holeNumber: holeNumber, value: strokes)
                            }
                        }
                    } label: {
                        HStack {
                            Text(menuScoreLabel(value: strokes, par: par))
                                .foregroundStyle(currentValue == strokes ? effectiveAccent : palette.foregroundColor)
                            Spacer(minLength: 0)
                            if currentValue == strokes {
                                Icon(name: "checkmark", size: 16, weight: .semibold)
                                    .foregroundStyle(effectiveAccent)
                            }
                        }
                    }
                }
            }
        }
        
        if currentValue != nil {
            Section {
                Button("Clear", role: .destructive) {
                    Haptics.fire(.light)
                    Task {
                        await viewModel.clearScore(scoringUnitID: row.scoringUnitID, participant: row.participant, holeNumber: holeNumber)
                    }
                }
            }
        }
    }
    
    func detailColumnCell(row: ScorecardRow, column: ScorecardColumn) -> some View {
        switch row {
        case .player(let leaderboardRow):
            switch column {
            case .hole(let holeNumber):
                return AnyView(detailCell(row: row, holeNumber: holeNumber))
            case .out(let holes), .inSegment(let holes):
                return AnyView(segmentSummaryCell(row: leaderboardRow, holes: holes))
            case .total:
                return AnyView(totalScoreLabel(for: leaderboardRow))
            }
        }
    }
    
    func segmentSummaryCell(row: LiveRoundViewModel.LeaderboardRow, holes: [Int]) -> some View {
        let summary = segmentScoreSummary(for: row, holes: holes)
        
        return VStack(spacing: 2) {
            Text(summary.primary)
                .fontStyle(kFontName, size: 13, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            
            Text(summary.secondary)
                .fontStyle(kFontName, size: 9, weight: .medium)
                .foregroundStyle(Color.neutral2)
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
        //.glassCardOverlay(cornerRadius: 0)//layout.stickyHeaderCornerRadius)
        .glassCardEffect(
            cornerRadius: 0,
            material: .bar,
            interactive: false,
            forceMaterial: true,
            tint: nil,
            strokeOpacity: 0,
            shadowOpacity: 0
        )
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
            if showPar {
                stickyCompactLabelCell("Par", height: layout.headerParHeight)
            }
            if showYardage {
                stickyCompactLabelCell("Yards", height: layout.metaRowHeight)
            }
            if showHandicap {
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
            .foregroundStyle(kHeaderTextColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, layout.labelHorizontalPadding)
            .padding(.trailing, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
            .frame(height: height)
    }
    
    func playerLabel(_ row: LiveRoundViewModel.LeaderboardRow) -> some View {
        let name = scorecardPrimaryName(for: row)
        let partnerNames = scorecardSecondaryNames(for: row)
        let isSelected = row.id == selectedParticipantID
        let canEditParticipant = allowsScoreEditing && viewModel.canEditScorecard(participant: row.participant)
        let accrued = accruedScoreLabel(for: row)
        let accruedColor = isSelected ? participantHighlightStyle(for: row.participant).readableText : palette.foregroundColor
        
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
            
            HStack(spacing: 4) {
                if canEditParticipant {
                    Icon(name: "f0c0", size: 10, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                
                Text(name)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if partnerNames.isPopulated {
                Text(partnerNames.joined(separator: "\n"))
                    .fontStyle(kFontName, size: 10, weight: .medium)
                    .foregroundStyle(Color.neutral)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
            }
            
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
                selectedParticipantID.toggle(to: row.id)
                if isRotated { rightPanelContent = nil }
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
        let initials = row.isSharedScoreUnit ? scorecardSharedInitials(for: row) : row.participant.name.initials
        let isSelected = row.id == selectedParticipantID
        let canEditParticipant = allowsScoreEditing && viewModel.canEditScorecard(participant: row.participant)
        let accrued = accruedScoreLabel(for: row)
        let accruedColor = isSelected ? participantHighlightStyle(for: row.participant).readableText : palette.foregroundColor
        
        return VStack(alignment: .leading, spacing: 1) {
            Text(accrued)
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(accruedColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            
            HStack(spacing: 4) {
                Text(initials)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .lineLimit(1)
                
                if canEditParticipant {
                    Icon(name: "f0c0", size: 10, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
            }
            
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
        highlightColor: Color,
        highlightTextColor: Color? = nil
    ) -> some View {
        let displayed = viewModel.scoreBasis == .gross ? gross : net
        let isScored = gross != nil
        let value = isScored ? "\(displayed ?? 0)" : "—"
        let baseTextColor = isScored ? palette.foregroundColor : Color.neutral4
        let diff = (displayed ?? 0) - (par ?? 0)
        let isSolidShape = diff <= -2 || diff >= 2
        let textColor: Color = if isSelected && isScored && isSolidShape {
            Color.accessibleLabelOnSolidBackground(background: highlightColor, colorScheme: colorScheme)
        } else if isSelected && !isScored {
            highlightTextColor ?? highlightColor
        } else {
            baseTextColor
        }
        
        return VStack(spacing: 8) {
            ZStack {
                let color = viewModel.theme.color.opacity(colorScheme.isLight ? 0.2 : 0.3) //Color.neutral5
                scoreDecoration(par: par, strokes: displayed, color: isSelected ? highlightColor : color)
                
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

    func totalScoreLabel(for row: LiveRoundViewModel.LeaderboardRow) -> some View {
        let label = accruedScoreLabel(for: row)

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
    
    enum RightPanelContent: Equatable {
        case editVisibility
        case scoreEdit(ScoreEditAnchor)
    }
    
    struct ScoreEditAnchor: Identifiable, Equatable {
        let participant: RoundParticipant
        let scoringUnitID: String
        let title: String
        let holeNumber: Int
        var id: String { "\(scoringUnitID)_\(holeNumber)" }

        init(row: LiveRoundViewModel.LeaderboardRow, holeNumber: Int) {
            participant = row.participant
            scoringUnitID = row.scoringUnitID
            title = row.isSharedScoreUnit
                ? row.participants.map { $0.isSubstitute ? "\($0.name.fullName)*" : $0.name.fullName }.filter(\.isPopulated).joined(separator: " + ")
                : (row.participant.isSubstitute ? "\(row.participant.name.fullName)*" : row.participant.name.fullName)
            self.holeNumber = holeNumber
        }
        
        static func == (lhs: ScoreEditAnchor, rhs: ScoreEditAnchor) -> Bool {
            lhs.scoringUnitID == rhs.scoringUnitID && lhs.holeNumber == rhs.holeNumber
        }
    }
    
    func submitScoreEditCustom() async {
        guard let anchor = scoreEditAnchor else { return }
        guard let value = Int(scoreEditCustomText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            scoreEditShowCustomPrompt = false
            return
        }
        let currentValue = viewModel.scoringUnitScoreInputValue(scoringUnitID: anchor.scoringUnitID, holeNumber: anchor.holeNumber)
        if currentValue == value {
            await viewModel.clearScore(scoringUnitID: anchor.scoringUnitID, participant: anchor.participant, holeNumber: anchor.holeNumber)
        } else {
            await viewModel.setScoreInputValue(scoringUnitID: anchor.scoringUnitID, participant: anchor.participant, holeNumber: anchor.holeNumber, value: value)
        }
        scoreEditAnchor = nil
        scoreEditCustomText = ""
        scoreEditShowCustomPrompt = false
        rightPanelContent = nil
    }
    
    // MARK: - Supporting
    
    var floatingToolbar: some View {
        HStack(spacing: 10) {
            if viewModel.handicapsEnabled {
                grossNetPicker
                
                Line(color: Color.neutral3.opacity(0.7), .vertical)
                    .frame(height: 15)
            }
            
            filterMenuButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassCardEffect(shape: .capsule, interactive: false)
    }
    
    private var grossNetPicker: some View {
        Picker("", selection: $viewModel.scoreBasis) {
            Text("Gross").tag(ScoreBasis.gross)
            Text("Net").tag(ScoreBasis.net)
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
    }
    
    private var toolbarFooter: some View {
        HStack {
            if viewModel.handicapsEnabled {
                grossNetPicker
            }
            
            Spacer(minLength: 0)
            
            filterMenuButton
        }
    }
    
    private var toolbarOverlay: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [palette.backgroundColor, .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 100)
            .allowsHitTesting(false)
            
            floatingToolbar
                .offset(y: isFloatingToolbarVisible ? 0 : layout.toolbarHiddenOffset)
                .allowsHitTesting(isFloatingToolbarVisible)
                .padding(.bottom, isRotated ? layout.rotatedToolbarBottomPadding : 0)
        }
        .opacity(isFloatingToolbarVisible ? 1 : 0)
    }
    
    private var visiblePlayersSubtitle: String {
        viewModel.visibleParticipantIDsLabel()
    }
    
    var filterMenuButton: some View {
        Group {
            if isRotated {
                Button {
                    Haptics.fire(.light)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        toggleContent(to: .editVisibility)
                    }
                } label: {
                    NavButton(
                        style: .glass,
                        icon: rightPanelContent == nil ? "f0b0" : "f00c",
                        weight: rightPanelContent == nil ? .regular : .solid,
                        color: palette.foregroundColor
                    )
                    .disabled(true)
                    //filterMenuButtonLabel
                }
            } else {
                Menu {
                    Button {
                        Haptics.fire(.light)
                        showScorecardVisibilitySheet = true
                    } label: {
                        Text("Hide players")
                        Text(visiblePlayersSubtitle)
                    }
                    
                    Section(header: Text("Visibility within scorecard")) {
                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) { showPar.toggle() }
                        } label: {
                            Label("Par", systemImage: showPar ? "checkmark.circle.fill" : "circle")
                        }
                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) { showYardage.toggle() }
                        } label: {
                            Label("Yardage", systemImage: showYardage ? "checkmark.circle.fill" : "circle")
                        }
                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) { showHandicap.toggle() }
                        } label: {
                            Label("Handicap", systemImage: showHandicap ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    .menuActionDismissBehavior(.disabled)
                } label: {
                    NavButton(
                        style: .glass,
                        icon: "f0b0",
                        weight: .regular,
                        color: palette.foregroundColor
                    )
                    //.disabled(true)
                    //filterMenuButtonLabel
                }
                .menuStyle(.borderlessButton)
            }
        }
    }
    
    private var filterMenuButtonLabel: some View {
        let teamColor = viewModel.teamColor(for: selectedParticipantID.flatMap { id in viewModel.snapshot.participants.first(where: { $0.id == id }) } ?? participant)
        let style = AccessibleTeamColorStyle.resolve(
            teamColor: teamColor ?? effectiveAccent,
            palette: palette,
            colorScheme: colorScheme,
            surface: .solidFill
        )
        return HStack(spacing: 6) {
            Icon(name: "f06e", size: 13, weight: .regular)
            Text("Edit visibility")
                .fontStyle(kFontName, size: 13, weight: .semibold)
        }
        .foregroundStyle(style.solidFillText)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(style.accent)
        .clipShape(.capsule)
    }
    
    @ViewBuilder
    func rightPanelView(content: RightPanelContent) -> some View {
        VStack(spacing: 0) {
            //            HStack {
            //                Spacer(minLength: 0)
            //                NavButton(style: .glass, icon: "f00d", size: 12, color: palette.foregroundColor) {
            //                    Haptics.fire(.light)
            //                    withAnimation(.easeInOut(duration: 0.2)) {
            //                        rightPanelContent = nil
            //                    }
            //                }
            //            }
            //            .padding(.horizontal, 12)
            //            .padding(.top, 12)
            //            .padding(.bottom, 8)
            
            switch content {
            case .editVisibility:
                editVisibilityTileView
            case .scoreEdit(let anchor):
                scoreTileView(anchor: anchor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: layout.rightPanelWidth)
        .glassCardEffect(cornerRadius: 16, interactive: false)
        .padding(.leading, 12)
    }
    
    func toggleContent(to content: RightPanelContent? = nil) {
        if rightPanelContent == nil {
            rightPanelContent = content
        } else {
            rightPanelContent = nil
        }
    }
    
    private var editVisibilityTileView: some View {
        let pageWidth = layout.rightPanelWidth - 24  // account for horizontal padding
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                editVisibilityTogglesPage
                    .frame(width: pageWidth)
                    .id(0)
                PlayerVisibilitySelectorView(
                    viewModel: viewModel,
                    onDismiss: {
                        Haptics.fire(.light)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            editVisibilityPage = 0
                        }
                    }
                )
                .frame(width: pageWidth)
                .id(1)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $editVisibilityPage)
    }
    
    private var editVisibilityTogglesPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Visibility within scorecard")
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral2)
                    .alignLeading()
                
                Button {
                    Haptics.fire(.light)
                    withAnimation(.easeInOut(duration: 0.2)) { showPar.toggle() }
                } label: {
                    HStack {
                        Text("Par")
                        Spacer()
                        Icon(name: showPar ? "checkmark.circle.fill" : "circle", size: 24, weight: .regular)
                    }
                }
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                
                Button {
                    Haptics.fire(.light)
                    withAnimation(.easeInOut(duration: 0.2)) { showYardage.toggle() }
                } label: {
                    HStack {
                        Text("Yardage")
                        Spacer()
                        Icon(name: showYardage ? "checkmark.circle.fill" : "circle", size: 24, weight: .regular)
                    }
                }
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                
                Button {
                    Haptics.fire(.light)
                    withAnimation(.easeInOut(duration: 0.2)) { showHandicap.toggle() }
                } label: {
                    HStack {
                        Text("Handicap")
                        Spacer()
                        Icon(name: showHandicap ? "checkmark.circle.fill" : "circle", size: 24, weight: .regular)
                    }
                }
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(palette.foregroundColor)
                
                Divider()
                
                Button {
                    Haptics.fire(.light)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        editVisibilityPage = 1
                    }
                } label: {
                    HStack {
                        VStack(spacing: 2) {
                            Text("Hide players")
                                .alignLeading()
                            Text(visiblePlayersSubtitle)
                                .fontStyle(kFontName, size: 13, weight: .medium)
                                .foregroundStyle(Color.neutral2)
                                .alignLeading()
                        }
                        Spacer()
                        Icon(name: "chevron.right", size: 14, weight: .semibold)
                            .foregroundStyle(Color.neutral3)
                    }
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    func scoreTileView(anchor: ScoreEditAnchor) -> some View {
        let par = viewModel.hole(for: anchor.holeNumber)?.par ?? 4
        let currentValue = viewModel.scoringUnitScoreInputValue(scoringUnitID: anchor.scoringUnitID, holeNumber: anchor.holeNumber)
        let scoreValues: [Int]
        if viewModel.isFriendlyScoreInputMode {
            let configMax = viewModel.snapshot.gameFormat.configuration.maxScoreOverPar.friendlyMaxRelativeValue(for: par)
            scoreValues = Array(-4...configMax)
        } else {
            let configMax = viewModel.snapshot.gameFormat.configuration.maxScoreOverPar.maxScore(for: par)
            scoreValues = Array(1...configMax)
        }
        let participantColor = participantHighlightColor(for: anchor.participant)
        
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(anchor.title) \(kDot) Hole \(anchor.holeNumber)")
                    .fontStyle(kFontName, size: 13, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    //.foregroundStyle(participantHighlightColor(for: anchor.participant))
                
                Text(viewModel.isFriendlyScoreInputMode ? "Enter score relative to par" : "Enter gross score")
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(Color.neutral2)
                    //.foregroundStyle(participantHighlightColor(for: anchor.participant))
                
                Divider()
                
                ForEach(scoreValues, id: \.self) { strokes in
                    Button {
                        Haptics.fire(.light)
                        Task {
                            if currentValue == strokes {
                                await viewModel.clearScore(scoringUnitID: anchor.scoringUnitID, participant: anchor.participant, holeNumber: anchor.holeNumber)
                            } else {
                                await viewModel.setScoreInputValue(scoringUnitID: anchor.scoringUnitID, participant: anchor.participant, holeNumber: anchor.holeNumber, value: strokes)
                            }
                        }
                        //withAnimation(.easeInOut(duration: 0.2)) { rightPanelContent = nil }
                    } label: {
                        HStack {
                            Text(menuScoreLabel(value: strokes, par: par))
                                .fontStyle(kFontName, size: 15, weight: .medium)
                                .foregroundStyle(currentValue == strokes ? participantColor : Color.neutral2)
                                //.foregroundStyle(currentGross == strokes ? effectiveAccent : palette.foregroundColor)
                            Spacer(minLength: 0)
                            if currentValue == strokes {
                                Icon(name: "checkmark", size: 16, weight: .semibold)
                                    .foregroundStyle(palette.foregroundColor)//effectiveAccent)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Divider()
                
                if currentValue != nil {
                    Button("Clear (-)") {
                        Haptics.fire(.light)
                        Task {
                            await viewModel.clearScore(scoringUnitID: anchor.scoringUnitID, participant: anchor.participant, holeNumber: anchor.holeNumber)
                        }
                        withAnimation(.easeInOut(duration: 0.2)) { rightPanelContent = nil }
                    }
                    .fontStyle(kFontName, size: 15, weight: .medium)
                    .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    func rowBackgroundColor(for row: ScorecardRow, index: Int) -> Color {
        //let zebra = palette.backgroundColor.opacity(index.isEven ? 0.0 : 1.0)
        let opacity = colorScheme.isLight ? 0.75 : 0.2
        let zebra = Color.systemWhite.opacity(index.isEven ? 0.0 : opacity)
        
        switch row {
        case .player(let row):
            if row.id == selectedParticipantID {
                //let highlight = participantHighlightColor(for: row.participant)
                //return highlight.opacity(0.25)
                return zebra
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

    func grossStrokes(for row: LiveRoundViewModel.LeaderboardRow, holeNumber: Int) -> Int? {
        if row.isSharedScoreUnit {
            return viewModel.scoringUnitGrossStrokes(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber)
        }
        return viewModel.grossStrokes(for: row.participant.id, holeNumber: holeNumber)
    }

    func netStrokes(for row: LiveRoundViewModel.LeaderboardRow, holeNumber: Int) -> Int? {
        if row.isSharedScoreUnit {
            return viewModel.scoringUnitNetStrokes(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber)
        }
        return viewModel.netStrokesOnHole(participant: row.participant, holeNumber: holeNumber)
    }

    func strokesReceived(for row: LiveRoundViewModel.LeaderboardRow, holeNumber: Int) -> Int {
        if row.isSharedScoreUnit {
            return viewModel.scoringUnitStrokesReceived(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber)
        }
        return viewModel.strokesReceivedOnHole(participant: row.participant, holeNumber: holeNumber)
    }

    func scoreInputValue(for row: LiveRoundViewModel.LeaderboardRow, holeNumber: Int) -> Int? {
        if row.isSharedScoreUnit {
            return viewModel.scoringUnitScoreInputValue(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber)
        }
        return viewModel.scoreInputValue(for: row.participant.id, holeNumber: holeNumber)
    }

    func scorecardPrimaryName(for row: LiveRoundViewModel.LeaderboardRow) -> String {
        shortName(for: row.participant)
    }

    func scorecardSecondaryNames(for row: LiveRoundViewModel.LeaderboardRow) -> [String] {
        guard row.isSharedScoreUnit else { return [] }
        return row.participants.dropFirst().map { shortName(for: $0) }
    }

    func scorecardSharedInitials(for row: LiveRoundViewModel.LeaderboardRow) -> String {
        let initials = row.participants.prefix(3).compactMap { participant -> String? in
            let given = participant.name.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
            if let first = given.first {
                return String(first).uppercased()
            }
            let fullName = participant.name.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            return fullName.first.map { String($0).uppercased() }
        }
        return initials.joined()
    }
    
    func shortName(for participant: RoundParticipant) -> String {
        let name = viewModel.formatDisplayName(for: participant)
        return participant.isSubstitute ? "\(name)*" : name
    }
    
    private var tintedHeader: Color {
        kHeaderTextColor//.opacity(0.65)
    }
    
    func handicapColor(_ handicap: Int) -> Color {
        //let clamped = min(max(handicap, 1), 18)
        //let fraction = Double(clamped - 1) / 17.0
        return tintedHeader
        //return Color.systemError.interpolate(to: effectiveAccent, fraction: fraction)
    }
    
    func handicapColor(for holeNumber: Int) -> Color {
        return tintedHeader
        //guard let handicap = viewModel.hole(for: holeNumber)?.handicap else { return Color.neutral4 }
        //return handicapColor(handicap)
    }
    
    func yardageLabel(for holeNumber: Int) -> String {
        let yardage = viewModel.hole(for: holeNumber)?.yardage
        return yardage.map(String.init) ?? "—"
    }
    
    func handicapLabel(for holeNumber: Int) -> String {
        let value = viewModel.hole(for: holeNumber)?.handicap
        return value.map(String.init) ?? "—"
    }
    
    func participantHighlightStyle(for participant: RoundParticipant) -> AccessibleTeamColorStyle {
        AccessibleTeamColorStyle.resolve(
            teamColor: viewModel.teamColor(for: participant) ?? effectiveAccent,
            palette: palette,
            colorScheme: colorScheme,
            surface: .card
        )
    }

    func participantHighlightColor(for participant: RoundParticipant) -> Color {
        participantHighlightStyle(for: participant).accent.opacity(0.8)
    }

    func menuScoreLabel(value: Int, par: Int) -> String {
        if viewModel.isFriendlyScoreInputMode {
            return viewModel.friendlyScoreLabel(relativeToPar: value, par: par, format: .fullWithStrokes)
        }
        return viewModel.friendlyScoreLabel(strokes: value, par: par, format: .fullWithStrokes)
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

    func segmentScoreSummary(for row: LiveRoundViewModel.LeaderboardRow, holes: [Int]) -> (primary: String, secondary: String) {
        guard row.isSharedScoreUnit else {
            return segmentScoreSummary(for: row.participant, holes: holes)
        }

        let segmentScores = holes.compactMap { holeNumber -> (strokes: Int, par: Int)? in
            guard let par = viewModel.hole(for: holeNumber)?.par else { return nil }
            guard let gross = viewModel.scoringUnitGrossStrokes(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber) else { return nil }
            let net = viewModel.scoringUnitNetStrokes(scoringUnitID: row.scoringUnitID, holeNumber: holeNumber)
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

    func accruedScoreLabel(for row: LiveRoundViewModel.LeaderboardRow) -> String {
        guard row.isSharedScoreUnit else {
            return accruedScoreLabel(for: row.participant)
        }
        let score = viewModel.scoringUnitScoreToPar(scoringUnitID: row.scoringUnitID, basis: viewModel.scoreBasis)
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
                return .init(text: "\(holeNumber)", color: kHeaderTextColor)
            case .out:
                return .init(text: "OUT", color: kHeaderTextColor)
            case .inSegment:
                return .init(text: "IN", color: kHeaderTextColor)
            case .total:
                return .init(text: "TOT", color: kHeaderTextColor)
            }
        }
    }
    
    var parHeaderValues: [StickyValue] {
        scorecardColumns.map { column in
            switch column {
            case .hole(let holeNumber):
                return .init(text: parLabel(for: holeNumber), color: kHeaderTextColor)
            case .out(let holes), .inSegment(let holes):
                return .init(text: parTotalLabel(for: holes), color: kHeaderTextColor)
            case .total:
                return .init(text: totalParLabel, color: kHeaderTextColor)
            }
        }
    }
    
    var yardageHeaderValues: [StickyValue] {
        scorecardColumns.map { column in
            switch column {
            case .hole(let holeNumber):
                return .init(text: yardageLabel(for: holeNumber), color: kHeaderTextColor)
            case .out(let holes), .inSegment(let holes):
                return .init(text: totalYardsLabel(for: holes), color: kHeaderTextColor)
            case .total:
                return .init(text: totalYardsLabel, color: kHeaderTextColor)
            }
        }
    }
    
    var handicapHeaderValues: [StickyValue] {
        scorecardColumns.map { column in
            switch column {
            case .hole(let holeNumber):
                return .init(text: handicapLabel(for: holeNumber), color: handicapColor(for: holeNumber))
            case .out, .inSegment, .total:
                return .init(text: "", color: kHeaderTextColor)
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
        guard availableWidth > 0 else { return layout.cellWidth }
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
        var height = layout.headerHoleHeight
        if showPar { height += layout.rowSpacing + layout.headerParHeight }
        if showYardage { height += layout.rowSpacing + layout.metaRowHeight }
        if showHandicap { height += layout.rowSpacing + layout.metaRowHeight }
        return height
    }
    
    func rowHeight(for row: ScorecardRow) -> CGFloat {
        switch row {
        case .player(let row):
            let extraLines = row.isSharedScoreUnit ? max(0, row.participants.count - 1) : 0
            return layout.playerRowHeight + CGFloat(extraLines) * 14
        }
    }
    
    enum ScorecardRow: Identifiable {
        case player(LiveRoundViewModel.LeaderboardRow)
        
        var id: String {
            switch self {
            case .player(let row): return row.id
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
        let gridMargin: CGFloat = 16
        let screenEdgePadding: CGFloat = 12
        let stickyHeaderCornerRadius: CGFloat = 8
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
        let rightPanelWidth: CGFloat = 220
        
        let headerHoleHeight: CGFloat = 26
        let headerParHeight: CGFloat = 26
        let metaRowHeight: CGFloat = 26
        let playerRowHeight: CGFloat = 56
    }
}

// MARK: - Preview

private let mockTheme: GolfTheme = .purple

#Preview("Full Scorecard") {
    ZStack {
        BackgroundTheme(palette: DesignPalette(theme: .glass, scheme: .dark), theme: mockTheme)
            .frame(width: UIScreen.main.bounds.width)
            .ignoresSafeArea()
    }
    .fullScreenCover(isPresented: .true) {
        FullScorecardViewPreview()
            .presentationBackground(.ultraThinMaterial)
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
        vm.theme = mockTheme
        
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
