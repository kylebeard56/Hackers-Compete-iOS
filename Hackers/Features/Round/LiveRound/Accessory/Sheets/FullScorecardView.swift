//
//  FullScorecardView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/9/26.
//

import Charts
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

enum FullScorecardPresentation: Equatable {
    case modal
    case embeddedLiveTable
    case embeddedInsights
}

enum ScorecardInteractionMode: String, CaseIterable, Equatable {
    case view
    case edit

    var label: String { rawValue.capitalized }

    func allowsScoreEditing(
        presentation: FullScorecardPresentation,
        hasPermission: Bool
    ) -> Bool {
        guard hasPermission else { return false }
        switch presentation {
        case .modal:
            return true
        case .embeddedLiveTable:
            return self == .edit
        case .embeddedInsights:
            return false
        }
    }
}

@MainActor
final class FullScorecardPresentationState: ObservableObject {
    @Published var interactionMode: ScorecardInteractionMode = .view
    @Published var isRotated = false
    @Published var showPar = true
    @Published var showYardage = true
    @Published var showHandicap = true
    @Published var showPlayerVisibilitySheet = false

    func resetForTabExit() {
        interactionMode = .view
        isRotated = false
        showPlayerVisibilitySheet = false
    }
}

struct FullScorecardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject private var viewModel: LiveRoundViewModel
    @StateObject private var presentationState: FullScorecardPresentationState
    let participant: RoundParticipant
    let allowsScoreEditing: Bool
    let initialSelectedScoringUnitID: String?
    let presentation: FullScorecardPresentation
    let includedParticipantIDs: Set<String>?
    
    @State private var selectedParticipantID: String?
    @State private var horizontalOffset: CGFloat = 0
    @State private var verticalOffset: CGFloat = 0
    @State private var previousVerticalOffset: CGFloat = 0
    @State private var scrollDirection: Int = 0
    @State private var directionalScrollDistance: CGFloat = 0
    @State private var isFloatingToolbarVisible = true
    @State private var isUserDraggingVertically = false
    @State private var scoreDisplayMode: ScorecardScoringDisplay = .strokes
    @State private var scoreEditAnchor: ScoreEditAnchor?
    @State private var scoreEditCustomText: String = ""
    @State private var scoreEditShowCustomPrompt = false
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
        guard let includedParticipantIDs else {
            return viewModel.scorecardParticipants
        }
        return viewModel.scorecardParticipants.filter { row in
            includedParticipantIDs.contains(row.participant.id)
                || row.participants.contains(where: { includedParticipantIDs.contains($0.id) })
        }
    }

    private var isRotated: Bool { presentationState.isRotated }
    private var showPar: Bool { presentationState.showPar }
    private var showYardage: Bool { presentationState.showYardage }
    private var showHandicap: Bool { presentationState.showHandicap }
    private var usesExplicitEditMode: Bool { presentation == .embeddedLiveTable }
    
    var kHeaderTextColor: Color { palette.backgroundColor }

    init(
        viewModel: LiveRoundViewModel,
        participant: RoundParticipant,
        allowsScoreEditing: Bool = true,
        initialSelectedScoringUnitID: String? = nil,
        presentation: FullScorecardPresentation = .modal,
        presentationState: FullScorecardPresentationState? = nil,
        includedParticipantIDs: Set<String>? = nil
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _presentationState = StateObject(
            wrappedValue: presentationState ?? FullScorecardPresentationState()
        )
        self.participant = participant
        self.allowsScoreEditing = allowsScoreEditing
        self.initialSelectedScoringUnitID = initialSelectedScoringUnitID
        self.presentation = presentation
        self.includedParticipantIDs = includedParticipantIDs
    }
    
    // MARK: - Main Body ✅
    
    var body: some View {
        GeometryReader { geom in
            let layoutSize = isRotated
                ? CGSize(width: max(1, geom.size.height), height: max(1, geom.size.width))
                : CGSize(width: max(1, geom.size.width), height: max(1, geom.size.height))
            
            ZStack {
                VStack(spacing: layout.sectionSpacing) {
                    if presentation == .modal || isRotated {
                        topBar
                    }
                    
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
                .padding(
                    .top,
                    (presentation == .embeddedLiveTable || presentation == .embeddedInsights) && !isRotated
                        ? 0
                        : layout.topPadding
                )
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
        .background(viewModel.theme.color.opacity(presentation == .embeddedLiveTable ? 0.06 : 0.1))
        .onAppear {
            viewModel.set(snapshot: viewModel.snapshot)
            if selectedParticipantID == nil {
                selectedParticipantID = initialSelectedScoringUnitID ?? participant.id
            }
            resetUnavailableScoreDisplayMode()
            previousVerticalOffset = verticalOffset
        }
        .onChange(of: viewModel.snapshot.resolvedActiveTemplate.id) { _, _ in
            resetUnavailableScoreDisplayMode()
        }
        .onChange(of: verticalOffset) { _, newValue in
            handleVerticalScrollChange(newValue)
        }
        .onDisappear {
            if presentation == .embeddedLiveTable {
                presentationState.resetForTabExit()
            }
        }
        .sheet(isPresented: $presentationState.showPlayerVisibilitySheet) {
            ScorecardVisibilitySheet(
                viewModel: viewModel,
                onDismiss: { presentationState.showPlayerVisibilitySheet = false }
            )
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
            if presentation == .embeddedLiveTable {
                NavButton(
                    style: .glass,
                    icon: "f00d",
                    color: palette.foregroundColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        presentationState.isRotated = false
                    }
                }
            } else {
                NavButton(style: .glass, onTap: { dismiss() })
            }
            
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
                if allowsScoreEditing && presentation == .embeddedLiveTable {
                    interactionModePicker
                }

                if scoreDisplayModes.count > 1 {
                    scoreDisplayPicker
                }

                if viewModel.handicapsEnabled {
                    grossNetPicker
                }
                
                filterMenuButton
            }

            if presentation == .modal {
                NavButton(
                    style: .glass,
                    icon: isRotated ? "f066" : "f065",
                    weight: .regular,
                    color: palette.foregroundColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        presentationState.isRotated.toggle()
                    }
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
            let hasEditPermission = allowsScoreEditing && viewModel.canEditScorecard(participant: row.participant)
            let canEditParticipant = presentationState.interactionMode.allowsScoreEditing(
                presentation: presentation,
                hasPermission: hasEditPermission
            )
            let showsEditAffordance = usesExplicitEditMode && canEditParticipant
            let scoreCellView = scoreCell(
                par: par,
                gross: gross,
                net: net,
                strokesReceived: strokesReceived,
                isSelected: isSelected,
                highlightColor: accentColor,
                highlightTextColor: highlightStyle.readableText
            )
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accentColor.opacity(showsEditAffordance ? 0.1 : 0))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accentColor.opacity(showsEditAffordance ? 0.55 : 0), lineWidth: 1)
            }
            .animation(.easeInOut(duration: 0.18), value: presentationState.interactionMode)
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
                    if currentValue == strokes {
                        Label(menuScoreLabel(value: strokes, par: par), systemImage: "checkmark")
                    } else {
                        Text(menuScoreLabel(value: strokes, par: par))
                    }
                    if let subtitle = stablefordMenuSubtitle(value: strokes, par: par, row: row, holeNumber: holeNumber) {
                        Text(subtitle)
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
                        if currentValue == strokes {
                            Label(menuScoreLabel(value: strokes, par: par), systemImage: "checkmark")
                        } else {
                            Text(menuScoreLabel(value: strokes, par: par))
                        }
                        if let subtitle = stablefordMenuSubtitle(value: strokes, par: par, row: row, holeNumber: holeNumber) {
                            Text(subtitle)
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
        let teamStyle = participantHighlightStyle(for: row.participant)
        let canEditParticipant = presentationState.interactionMode.allowsScoreEditing(
            presentation: presentation,
            hasPermission: allowsScoreEditing && viewModel.canEditScorecard(participant: row.participant)
        )
        let accrued = accruedScoreLabel(for: row)
        let accruedColor = teamStyle.readableText
        
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
                Circle()
                    .fill(teamStyle.accent)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)

                if canEditParticipant {
                    Icon(name: "f0c0", size: 10, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                
                Text(name)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(teamStyle.readableText)
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
        .overlay(alignment: .leading) {
            Capsule()
                .fill(teamStyle.accent)
                .frame(width: 4)
                .padding(.vertical, 7)
                .accessibilityHidden(true)
        }
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
        let teamStyle = participantHighlightStyle(for: row.participant)
        let canEditParticipant = presentationState.interactionMode.allowsScoreEditing(
            presentation: presentation,
            hasPermission: allowsScoreEditing && viewModel.canEditScorecard(participant: row.participant)
        )
        let accrued = accruedScoreLabel(for: row)
        let accruedColor = teamStyle.readableText
        
        return VStack(alignment: .leading, spacing: 1) {
            Text(accrued)
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(accruedColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(teamStyle.accent)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)

                Text(initials)
                    .fontStyle(kFontName, size: 12, weight: .semibold)
                    .foregroundStyle(teamStyle.readableText)
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
        .overlay(alignment: .leading) {
            Capsule()
                .fill(teamStyle.accent)
                .frame(width: 4)
                .padding(.vertical, 7)
                .accessibilityHidden(true)
        }
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
        let value: String
        switch effectiveScoreDisplayMode {
        case .strokes:
            value = isScored ? "\(displayed ?? 0)" : "—"
        case .stableford:
            value = isScored ? "\(viewModel.stablefordPoints(displayedStrokes: displayed, par: par) ?? 0)" : "—"
        }
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
        let teamStyle = participantHighlightStyle(for: participant)
        
        return Text(label)
            .fontStyle(kFontName, size: 17, weight: .semibold)
            .foregroundStyle(teamStyle.readableText)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, layout.cellHorizontalPadding)
            .padding(.vertical, layout.cellVerticalPadding)
    }

    func totalScoreLabel(for row: LiveRoundViewModel.LeaderboardRow) -> some View {
        let label = accruedScoreLabel(for: row)
        let teamStyle = participantHighlightStyle(for: row.participant)

        return Text(label)
            .fontStyle(kFontName, size: 17, weight: .semibold)
            .foregroundStyle(teamStyle.readableText)
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

    enum ScorecardScoringDisplay: String, CaseIterable {
        case strokes
        case stableford

        var label: String {
            switch self {
            case .strokes: "Strokes"
            case .stableford: "Stableford"
            }
        }
    }

    var scoreDisplayModes: [ScorecardScoringDisplay] {
        var modes: [ScorecardScoringDisplay] = [.strokes]
        if viewModel.availableLeaderboardChips.contains(.stableford) {
            modes.append(.stableford)
        }
        return modes
    }

    var effectiveScoreDisplayMode: ScorecardScoringDisplay {
        scoreDisplayModes.contains(scoreDisplayMode) ? scoreDisplayMode : .strokes
    }

    func resetUnavailableScoreDisplayMode() {
        if !scoreDisplayModes.contains(scoreDisplayMode) {
            scoreDisplayMode = .strokes
        }
    }

    var floatingToolbar: some View {
        HStack(spacing: 10) {
            if scoreDisplayModes.count > 1 {
                scoreDisplayPicker
            }

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

    private var scoreDisplayPicker: some View {
        Picker("", selection: $scoreDisplayMode) {
            ForEach(scoreDisplayModes, id: \.rawValue) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 168)
    }

    private var interactionModePicker: some View {
        Picker("Table interaction", selection: $presentationState.interactionMode) {
            ForEach(ScorecardInteractionMode.allCases, id: \.self) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 126)
        .accessibilityHint("Edit mode enables score cells you are allowed to change")
    }
    
    private var toolbarFooter: some View {
        Group {
            if presentation == .embeddedLiveTable {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if allowsScoreEditing {
                            interactionModePicker
                        }

                        if scoreDisplayModes.count > 1 {
                            scoreDisplayPicker
                        }

                        if viewModel.handicapsEnabled {
                            grossNetPicker
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                modalToolbarFooter
            }
        }
    }

    private var modalToolbarFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                if scoreDisplayModes.count > 1 {
                    scoreDisplayPicker
                }

                if viewModel.handicapsEnabled {
                    grossNetPicker
                }

                Spacer(minLength: 0)

                filterMenuButton
            }

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    if scoreDisplayModes.count > 1 {
                        scoreDisplayPicker
                    }

                    if viewModel.handicapsEnabled {
                        grossNetPicker
                    }
                }

                Spacer(minLength: 0)

                filterMenuButton
            }
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
                        presentationState.showPlayerVisibilitySheet = true
                    } label: {
                        Text("Hide players")
                        Text(visiblePlayersSubtitle)
                    }
                    
                    Section(header: Text("Visibility within scorecard")) {
                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) { presentationState.showPar.toggle() }
                        } label: {
                            Label("Par", systemImage: showPar ? "checkmark.circle.fill" : "circle")
                        }
                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) { presentationState.showYardage.toggle() }
                        } label: {
                            Label("Yardage", systemImage: showYardage ? "checkmark.circle.fill" : "circle")
                        }
                        Button {
                            Haptics.fire(.light)
                            withAnimation(.easeInOut(duration: 0.2)) { presentationState.showHandicap.toggle() }
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
                    withAnimation(.easeInOut(duration: 0.2)) { presentationState.showPar.toggle() }
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
                    withAnimation(.easeInOut(duration: 0.2)) { presentationState.showYardage.toggle() }
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
                    withAnimation(.easeInOut(duration: 0.2)) { presentationState.showHandicap.toggle() }
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
        switch row {
        case .player(let row):
            let teamStyle = participantHighlightStyle(for: row.participant)
            if row.id == selectedParticipantID {
                return teamStyle.accent.opacity(colorScheme.translucent(0.16, 0.22))
            }
            return teamStyle.subtleFill.opacity(index.isEven ? 0.72 : 1)
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

    func stablefordMenuSubtitle(
        value: Int,
        par: Int,
        row: LiveRoundViewModel.LeaderboardRow,
        holeNumber: Int
    ) -> String? {
        guard scoreDisplayModes.contains(.stableford) else { return nil }
        let grossRelativeToPar = viewModel.isFriendlyScoreInputMode ? value : value - par
        let handicapAdjustment = viewModel.scoreBasis == .net ? strokesReceived(for: row, holeNumber: holeNumber) : 0
        let points = viewModel.stablefordPoints(scoreToPar: grossRelativeToPar - handicapAdjustment)
        return "\(points) Stableford"
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
        if effectiveScoreDisplayMode == .stableford {
            let points = viewModel.stablefordPointSummary(for: participant, holes: holes)
            guard points.scoredCount > 0 else { return ("—", "") }
            return ("\(points.total)", "Pts")
        }

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
        if effectiveScoreDisplayMode == .stableford {
            let points = viewModel.stablefordPointSummary(for: row, holes: holes)
            guard points.scoredCount > 0 else { return ("—", "") }
            return ("\(points.total)", "Pts")
        }

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
        if effectiveScoreDisplayMode == .stableford {
            return "\(viewModel.stablefordPointSummary(for: participant).total)"
        }

        let score = viewModel.scoreToPar(for: participant, basis: viewModel.scoreBasis)
        return scoreToParLabel(score)
    }

    func accruedScoreLabel(for row: LiveRoundViewModel.LeaderboardRow) -> String {
        if effectiveScoreDisplayMode == .stableford {
            return "\(viewModel.stablefordPointSummary(for: row).total)"
        }

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

private struct CumulativeScorePoint: Identifiable {
    let holesCompleted: Int
    let value: Int

    var id: Int { holesCompleted }
}

private struct CumulativeScoreBandPoint: Identifiable {
    let holesCompleted: Int
    let lower: Int
    let median: Int
    let upper: Int

    var id: Int { holesCompleted }
}

struct PlayerInsightsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: LiveRoundViewModel
    let participant: RoundParticipant

    @State private var selectedBasis: ScoreBasis
    @State private var projection: PlayerFinishProjection?
    @State private var isLoadingProjection = false

    init(viewModel: LiveRoundViewModel, participant: RoundParticipant) {
        self.viewModel = viewModel
        self.participant = participant
        _selectedBasis = State(initialValue: viewModel.handicapsEnabled ? .net : .gross)
    }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    private var basis: ScoreBasis { selectedBasis }
    private var basisDisplayName: String { basis == .net ? "Net" : "Gross" }
    private var canRevealInsights: Bool { viewModel.canRevealInsights(for: participant) }
    private var projectionUnavailableReason: String? {
        viewModel.playerProjectionUnavailableReason(for: participant)
    }
    private var actualTrend: [ProjectionTrendPoint] {
        projection?.actualTrend ?? viewModel.actualScoreTrend(for: participant, basis: basis)
    }
    private var holesCompleted: Int { actualTrend.count }
    private var totalHoleCount: Int { viewModel.holeNumbers.count }
    private var isPlayerRoundComplete: Bool {
        totalHoleCount > 0 && holesCompleted == totalHoleCount
    }
    private var currentScore: Int { viewModel.scoreToPar(for: participant, basis: basis) }
    private var averagePaceTrend: [ProjectionTrendPoint]? {
        viewModel.completedAveragePaceTrend(for: participant, basis: basis)
    }
    private var handicapUsage: HandicapStrokeUsage {
        viewModel.handicapStrokeUsage(for: participant)
    }
    private var outcomeCounts: [GrossScoreOutcomeCount] {
        viewModel.grossScoreOutcomeCounts(for: participant)
    }
    private var projectionTaskID: String {
        viewModel.playerProjectionRevision(for: participant, scoreBasis: basis)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    identityCard

                    if canRevealInsights {
                        if viewModel.handicapsEnabled {
                            Picker("Score basis", selection: $selectedBasis) {
                                Text("Gross").tag(ScoreBasis.gross)
                                Text("Net").tag(ScoreBasis.net)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityHint("Changes the player summary and cumulative score chart")
                        }

                        currentRoundCard

                        IndividualScorecardView(
                            viewModel: viewModel,
                            participant: participant,
                            presentation: .embedded,
                            showsPlayerHeader: false
                        )

                        trendCard

                        if holesCompleted > 0 {
                            scoringMixCard
                        }
                    } else {
                        ContentUnavailableView(
                            "Scores hidden",
                            systemImage: "eye.slash",
                            description: Text(
                                "This player’s score details will appear when secret scoring is revealed."
                            )
                        )
                        .padding(24)
                    }
                }
                .padding(16)
                .padding(.bottom, 16)
            }
            .background(palette.backgroundColor.opacity(0.98))
            .navigationTitle("Player insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .task(id: projectionTaskID) {
            projection = nil
            isLoadingProjection = false
            guard canRevealInsights,
                  holesCompleted >= 3,
                  !isPlayerRoundComplete,
                  projectionUnavailableReason == nil else { return }
            isLoadingProjection = true
            projection = await viewModel.playerProjection(for: participant, scoreBasis: basis)
            isLoadingProjection = false
        }
    }

    private var identityCard: some View {
        let accent = viewModel.teamColor(for: participant) ?? viewModel.theme.color
        let isFavorite = viewModel.pinnedParticipantIDs.contains(participant.id)

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(accent)
                .frame(width: 5, height: 48)

            PlayerAvatarView(
                initials: participant.name.initials,
                size: 54,
                fillColor: accent.opacity(0.24),
                glassTint: accent.opacity(0.18)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name.fullName)
                    .fontStyle(kFontName, size: 20, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Text(participant.lockedHandicapProvenance)
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .foregroundStyle(Color.neutral)
            }
            Spacer(minLength: 0)

            Button {
                Haptics.fire(.light)
                viewModel.togglePinned(participant)
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isFavorite ? accent : Color.neutral2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Stop following \(participant.name.fullName)" : "Follow \(participant.name.fullName)")
            .accessibilityHint("Followed players are pinned in this round’s leaderboard")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(
            cornerRadius: 26,
            interactive: false,
            forceMaterial: true,
            tint: accent.opacity(colorScheme.isLight ? 0.09 : 0.16),
            strokeOpacity: 0.65
        )
        .accessibilityElement(children: .contain)
    }

    private var currentRoundCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                insightMetric(title: basis == .gross ? "Gross" : "Net", value: scoreLabel(currentScore))
                Divider().frame(height: 40)
                insightMetric(title: "Holes", value: "\(holesCompleted)")
                Divider().frame(height: 40)
                insightMetric(title: "HCP", value: "\(participant.lockedHandicapAllowance)")
            }

            if shouldShowHandicapUsage {
                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HCP strokes")
                            .fontStyle(kFontName, size: 12, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Text(upcomingHandicapText)
                            .fontStyle(kFontName, size: 11, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)
                    compactInsightMetric(title: "Used", value: strokeCountLabel(handicapUsage.used))
                    compactInsightMetric(title: "Left", value: strokeCountLabel(handicapUsage.remaining))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false, forceMaterial: true)
        .accessibilityElement(children: .combine)
    }

    private func insightMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .fontStyle(kFontName, size: 22, weight: .bold)
                .foregroundStyle(palette.foregroundColor)
                .contentTransition(.numericText())
            Text(title)
                .fontStyle(kFontName, size: 11, weight: .medium)
                .foregroundStyle(Color.neutral)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private func compactInsightMetric(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .fontStyle(kFontName, size: 18, weight: .bold)
                .foregroundStyle(palette.foregroundColor)
                .contentTransition(.numericText())
            Text(title)
                .fontStyle(kFontName, size: 10, weight: .medium)
                .foregroundStyle(Color.neutral)
                .textCase(.uppercase)
        }
        .frame(minWidth: 44)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(basisDisplayName) score projection")
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    Text("Solid: played · Shaded: projected 80% range")
                        .fontStyle(kFontName, size: 12, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 8)
                if let projection {
                    Text("\(projection.confidence.rawValue.capitalized) confidence")
                        .fontStyle(kFontName, size: 11, weight: .semibold)
                        .foregroundStyle(viewModel.theme.color)
                }
            }

            if actualTrend.isEmpty {
                emptyTrendState
            } else {
                scoreTrendChart
                    .frame(height: 220)

                projectionSummary
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(interactive: false, forceMaterial: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }

    private var scoreTrendChart: some View {
        Chart {
            RuleMark(y: .value("Even", 0))
                .foregroundStyle(Color.neutral2.opacity(0.8))
                .lineStyle(.init(lineWidth: 1.5, dash: [5, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Even")
                        .fontStyle(kFontName, size: 10, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                }

            if let averageStrokeTrend {
                ForEach(averageStrokeTrend) { point in
                    LineMark(
                        x: .value("Holes completed", point.holesCompleted),
                        y: .value("Average pace", point.value),
                        series: .value("Series", "Average pace")
                    )
                    .foregroundStyle(Color.neutral2)
                    .lineStyle(.init(lineWidth: 2, dash: [2, 5]))
                }
            }

            if projection != nil {
                ForEach(projectedStrokeTrend) { point in
                    AreaMark(
                        x: .value("Holes completed", point.holesCompleted),
                        yStart: .value("Low", point.lower),
                        yEnd: .value("High", point.upper)
                    )
                    .foregroundStyle(viewModel.theme.color.opacity(0.16))

                    LineMark(
                        x: .value("Holes completed", point.holesCompleted),
                        y: .value("Projection low", point.lower),
                        series: .value("Projection edge", "Low")
                    )
                    .foregroundStyle(viewModel.theme.color.opacity(0.3))
                    .lineStyle(.init(lineWidth: 1))

                    LineMark(
                        x: .value("Holes completed", point.holesCompleted),
                        y: .value("Projection high", point.upper),
                        series: .value("Projection edge", "High")
                    )
                    .foregroundStyle(viewModel.theme.color.opacity(0.3))
                    .lineStyle(.init(lineWidth: 1))

                    LineMark(
                        x: .value("Holes completed", point.holesCompleted),
                        y: .value("Projected median", point.median)
                    )
                    .foregroundStyle(viewModel.theme.color.opacity(0.65))
                    .lineStyle(.init(lineWidth: 2, dash: [5, 4]))
                }

                RuleMark(x: .value("Projection starts", holesCompleted))
                    .foregroundStyle(Color.neutral2.opacity(0.55))
                    .lineStyle(.init(lineWidth: 1, dash: [2, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Projection")
                            .fontStyle(kFontName, size: 9, weight: .semibold)
                            .foregroundStyle(Color.neutral)
                    }

                if let finish = projectedStrokeTrend.last {
                    PointMark(
                        x: .value("Finish hole", finish.holesCompleted),
                        y: .value("Projected finish", finish.median)
                    )
                    .foregroundStyle(viewModel.theme.color.opacity(0.75))
                    .symbolSize(42)
                    .annotation(position: .top, alignment: .trailing, spacing: 6) {
                        scoreChartLabel("Projected \(scoreLabel(finish.median))")
                    }
                }
            }

            ForEach(actualChartTrend) { point in
                LineMark(
                    x: .value("Holes completed", point.holesCompleted),
                    y: .value("Score to par", point.value),
                    series: .value("Series", "Actual")
                )
                .foregroundStyle(viewModel.theme.color)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))

                if point.holesCompleted != 0 {
                    PointMark(
                        x: .value("Holes completed", point.holesCompleted),
                        y: .value("Score to par", point.value)
                    )
                    .foregroundStyle(viewModel.theme.color)
                }
            }

            if let current = actualChartTrend.last, current.holesCompleted > 0 {
                PointMark(
                    x: .value("Current hole", current.holesCompleted),
                    y: .value("Current score", current.value)
                )
                .foregroundStyle(viewModel.theme.color)
                .symbolSize(52)
                .annotation(position: .top, alignment: .leading, spacing: 6) {
                    scoreChartLabel("Now \(scoreLabel(current.value))")
                }
            }
        }
        .chartXScale(domain: 0...max(1, totalHoleCount))
        .chartYScale(domain: chartYDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine().foregroundStyle(Color.neutral5.opacity(0.14))
                AxisValueLabel {
                    if let holes = value.as(Int.self) {
                        Text(holes == 0 ? "Start" : "\(holes)")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.neutral5.opacity(0.14))
                AxisValueLabel {
                    if let score = value.as(Int.self) { Text(scoreLabel(score)) }
                }
            }
        }
    }

    private func scoreChartLabel(_ text: String) -> some View {
        Text(text)
            .fontStyle(kFontName, size: 10, weight: .semibold)
            .foregroundStyle(palette.foregroundColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }

    @ViewBuilder
    private var projectionSummary: some View {
        if isPlayerRoundComplete, let average = averagePacePerHole {
            Label(
                "Average pace \(signedDecimal(average)) per hole · below is hot, above is cold",
                systemImage: "line.diagonal"
            )
            .fontStyle(kFontName, size: 12, weight: .medium)
            .foregroundStyle(Color.neutral)
        } else if holesCompleted < 3 {
            Label("Finish projection unlocks after three recorded holes.", systemImage: "chart.line.uptrend.xyaxis")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
        } else if isLoadingProjection {
            HStack(spacing: 8) {
                ProgressView()
                Text("Updating finish projection…")
            }
            .fontStyle(kFontName, size: 13, weight: .medium)
            .foregroundStyle(Color.neutral)
        } else if let projection {
            VStack(alignment: .leading, spacing: 5) {
                Text("Projected \(basis.rawValue) finish: \(scoreLabel(projection.lowerFinish)) to \(scoreLabel(projection.upperFinish))")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text("Most likely \(scoreLabel(projection.medianFinish)) · 80% range · based on \(projection.sampleCount) similar rounds")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
        } else {
            Text(projectionUnavailableReason ?? "A projection isn’t available for this scoring format yet.")
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral)
        }
    }

    private var scoringMixCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gross scoring mix")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                Text("Hole outcomes · clockwise from best to worst")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            GrossScoringRadarChart(
                outcomes: outcomeCounts,
                foregroundColor: palette.foregroundColor,
                accessibilityLabel: scoringMixAccessibilityLabel
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardEffect(interactive: false, forceMaterial: true)
    }

    private var emptyTrendState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title2)
            Text("Record a hole to start the score trend.")
                .fontStyle(kFontName, size: 13, weight: .medium)
        }
        .foregroundStyle(Color.neutral)
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private var accessibilitySummary: String {
        var summary = "Cumulative \(basis.rawValue) score through \(holesCompleted) holes, \(scoreLabel(currentScore))."
        if let projection {
            summary += " Projected 80 percent finish interval \(scoreLabel(projection.lowerFinish)) to \(scoreLabel(projection.upperFinish)), median \(scoreLabel(projection.medianFinish)), \(projection.confidence.rawValue) confidence."
        } else if let average = averagePacePerHole {
            summary += " Completed-round average pace \(signedDecimal(average)) per hole."
        }
        return summary
    }

    private var actualChartTrend: [CumulativeScorePoint] {
        guard actualTrend.isPopulated else { return [] }
        let baseline = CumulativeScorePoint(
            holesCompleted: 0,
            value: 0
        )
        let points = actualTrend.enumerated().map { index, point in
            CumulativeScorePoint(holesCompleted: index + 1, value: point.value)
        }
        return [baseline] + points
    }

    private var chartYDomain: ClosedRange<Int> {
        var values = actualChartTrend.map(\.value)
        values.append(contentsOf: projectedStrokeTrend.flatMap { [$0.lower, $0.median, $0.upper] })
        values.append(contentsOf: averageStrokeTrend?.map(\.value) ?? [])

        let lowerValue = min(0, values.min() ?? 0)
        let upperValue = max(0, values.max() ?? 0)
        let span = max(1, upperValue - lowerValue)
        let padding = max(2, Int(ceil(Double(span) * 0.12)))
        return (lowerValue - padding)...(upperValue + padding)
    }

    private var projectedStrokeTrend: [CumulativeScoreBandPoint] {
        guard let projection else { return [] }
        return projection.projectedTrend.compactMap { point in
            guard let holesCompleted = completionCount(for: point.holeNumber) else { return nil }
            return CumulativeScoreBandPoint(
                holesCompleted: holesCompleted,
                lower: point.lower,
                median: point.median,
                upper: point.upper
            )
        }
    }

    private var averageStrokeTrend: [CumulativeScorePoint]? {
        averagePaceTrend?.compactMap { point in
            guard let holesCompleted = completionCount(for: point.holeNumber) else { return nil }
            return CumulativeScorePoint(
                holesCompleted: holesCompleted,
                value: point.value
            )
        }
    }

    private func completionCount(for holeNumber: Int) -> Int? {
        if let index = viewModel.courseOrderHoleNumbers.firstIndex(of: holeNumber) {
            return index + 1
        }
        guard let firstHole = viewModel.courseOrderHoleNumbers.first,
              holeNumber == max(0, firstHole - 1) else { return nil }
        return 0
    }

    private var averagePacePerHole: Double? {
        guard isPlayerRoundComplete, let final = actualTrend.last else { return nil }
        return Double(final.value) / Double(max(1, holesCompleted))
    }

    private var shouldShowHandicapUsage: Bool {
        viewModel.handicapsEnabled
            && holesCompleted > 0
            && !isPlayerRoundComplete
            && handicapUsage.total != 0
    }

    private var upcomingHandicapText: String {
        let allocations = handicapUsage.remainingAllocations
        guard allocations.isPopulated else { return "No handicap strokes remaining" }
        let visible = allocations.prefix(4).map {
            "H\($0.holeNumber) \(strokeCountLabel($0.strokes))"
        }
        let remainder = allocations.count - visible.count
        return "Upcoming: \(visible.joined(separator: " · "))\(remainder > 0 ? " · +\(remainder) more" : "")"
    }

    private var scoringMixAccessibilityLabel: String {
        let values = outcomeCounts.map { "\($0.bucket.label), \($0.count)" }
        return "Gross scoring mix, arranged clockwise from best to worst outcome. \(values.joined(separator: ", "))."
    }

    private func strokeCountLabel(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        if value < 0 { return "−\(abs(value))" }
        return "0"
    }

    private func signedDecimal(_ value: Double) -> String {
        let formatted = String(format: "%.2f", abs(value))
        if value > 0 { return "+\(formatted)" }
        if value < 0 { return "−\(formatted)" }
        return "0.00"
    }

    private func scoreLabel(_ value: Int) -> String {
        if value == 0 { return "E" }
        return value > 0 ? "+\(value)" : "\(value)"
    }
}

private struct GrossScoringRadarChart: View {
    let outcomes: [GrossScoreOutcomeCount]
    let foregroundColor: Color
    let accessibilityLabel: String

    private var chartOutcomes: [GrossScoreOutcomeCount] {
        let outcomesByBucket = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.bucket, $0) })
        return GrossScoreOutcomeBucket.qualityRadarOrder.compactMap { outcomesByBucket[$0] }
    }

    private var maximumCount: Int {
        max(1, chartOutcomes.map(\.count).max() ?? 0)
    }

    private var normalizedValues: [CGFloat] {
        chartOutcomes.map { outcome in
            guard outcome.count > 0 else { return 0.12 }
            let normalizedCount = CGFloat(outcome.count) / CGFloat(maximumCount)
            return 0.2 + (normalizedCount * 0.8)
        }
    }

    private var categoryColors: [Color] {
        chartOutcomes.map { color(for: $0.bucket) }
    }

    private var shapeGradient: AngularGradient {
        let count = max(1, categoryColors.count)
        let stops = categoryColors.enumerated().map { index, color in
            Gradient.Stop(color: color, location: Double(index) / Double(count))
        } + [Gradient.Stop(color: categoryColors[0], location: 1)]
        return AngularGradient(
            gradient: Gradient(stops: stops),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = max(0, min(geometry.size.width - 122, geometry.size.height - 76) / 2)
            let outerPoints = points(
                center: center,
                radius: radius,
                values: Array(repeating: 1, count: chartOutcomes.count)
            )
            let valuePoints = points(center: center, radius: radius, values: normalizedValues)

            ZStack {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RadarPolygon(
                        points: points(
                            center: center,
                            radius: radius,
                            values: Array(repeating: CGFloat(level), count: chartOutcomes.count)
                        )
                    )
                    .stroke(
                        Color.neutral5.opacity(0.65),
                        lineWidth: level == 1 ? 1.5 : 1
                    )
                }

                ForEach(chartOutcomes.indices, id: \.self) { index in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: outerPoints[index])
                    }
                    .stroke(Color.neutral5.opacity(0.55), lineWidth: 1)
                }

                ForEach([12.0, 9.0, 6.0, 3.0], id: \.self) { depth in
                    RadarPolygon(points: valuePoints)
                        .fill(Color.accentPurple.opacity(0.035))
                        .offset(y: depth)
                }

                RadarPolygon(points: valuePoints)
                    .fill(shapeGradient)
                    .opacity(0.26)

                RadarPolygon(points: valuePoints)
                    .stroke(shapeGradient, style: .init(lineWidth: 2.5, lineJoin: .round))

                ForEach(Array(chartOutcomes.enumerated()), id: \.element.id) { index, outcome in
                    if outcome.count > 0 {
                        Circle()
                            .fill(categoryColors[index])
                            .frame(width: 7, height: 7)
                            .position(valuePoints[index])
                    }

                    axisLabel(for: outcome, color: categoryColors[index])
                        .frame(width: 74)
                        .position(
                            point(
                                index: index,
                                center: center,
                                radius: radius + 34,
                                value: 1
                            )
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.18, contentMode: .fit)
        .frame(maxHeight: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func axisLabel(
        for outcome: GrossScoreOutcomeCount,
        color: Color
    ) -> some View {
        VStack(spacing: 2) {
            Text(shortLabel(for: outcome.bucket))
                .fontStyle(kFontName, size: 10, weight: .medium)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("\(outcome.count)")
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(outcome.count > 0 ? color : foregroundColor.opacity(0.5))
                .contentTransition(.numericText())
        }
    }

    private func shortLabel(for bucket: GrossScoreOutcomeBucket) -> String {
        switch bucket {
        case .birdieOrBetter: "Birdie+"
        case .par: "Par"
        case .bogey: "Bogey"
        case .doubleBogey: "Double"
        case .tripleBogey: "Triple+"
        }
    }

    private func color(for bucket: GrossScoreOutcomeBucket) -> Color {
        switch bucket {
        case .birdieOrBetter: .accentGreen
        case .par: .accentPurple
        case .bogey: .accentYellow
        case .doubleBogey: .systemOrange
        case .tripleBogey: .systemError
        }
    }

    private func points(
        center: CGPoint,
        radius: CGFloat,
        values: [CGFloat]
    ) -> [CGPoint] {
        values.indices.map { index in
            point(index: index, center: center, radius: radius, value: values[index])
        }
    }

    private func point(
        index: Int,
        center: CGPoint,
        radius: CGFloat,
        value: CGFloat
    ) -> CGPoint {
        let angle = (-Double.pi / 2) + (Double(index) * 2 * Double.pi / Double(chartOutcomes.count))
        let clampedValue = min(1, max(0, value))
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius * clampedValue,
            y: center.y + CGFloat(sin(angle)) * radius * clampedValue
        )
    }
}

private struct RadarPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
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
