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
    var scorecardAsset: StorageAsset? = nil

    @State private var showScorecardOverlay = false
    @State private var scorecardOverlayImage: UIImage?
    @State private var scorecardLoadComplete = false
    @State private var scorecardOverlayScale: CGFloat = 1
    @State private var scorecardOverlayOffset: CGSize = .zero

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }
    private var hasAttachedScorecard: Bool {
        scorecardAsset ?? viewModel.snapshot.round.completedPlayers
            .first { $0.playerID == participant.playerID }?.scorecardStorageID != nil
    }
    private var resolvedScorecardAsset: StorageAsset? {
        scorecardAsset ?? viewModel.snapshot.round.completedPlayers
            .first { $0.playerID == participant.playerID }?.scorecardStorageID
    }
    private var holeNumbers: [Int] { viewModel.holeNumbers }
    private var handicapsEnabled: Bool { viewModel.handicapsEnabled }
    private var scoreBasis: ScoreBasis { viewModel.scoreBasis }
    private var effectiveAccent: Color {
        viewModel.teamColor(for: participant) ?? viewModel.theme.color
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    //navPadding

                    playerHeader
                    totalScoreCallout
                    scorecardButton
                    frontNineTile
                    backNineTile
                    courseDateFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, UIApplication.shared.topSafeAreaInset + 16)
                .padding(.bottom, 60)
            }

            scorecardNavHeader
                .padding(.top, 16)
                .padding(.horizontal, 16)
                .alignTop()
        }
        .background(palette.backgroundColor)
        .navigationBarBackButtonHidden(true)
        .overlay { scorecardOverlay }
    }

    @ViewBuilder
    private var scorecardButton: some View {
        if hasAttachedScorecard {
            Button {
                Haptics.fire(.light)
                showScorecardOverlay = true
                scorecardLoadComplete = false
                Task {
                    if let asset = resolvedScorecardAsset {
                        scorecardOverlayImage = try? await FirebaseService.shared.fetchScorecardImage(asset: asset)
                    }
                    scorecardLoadComplete = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 14, weight: .medium))
                    Text("Scorecard")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                }
                .foregroundStyle(palette.foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .glassCardEffect(interactive: true)
        }
    }

    @ViewBuilder
    private var scorecardOverlay: some View {
        if showScorecardOverlay {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showScorecardOverlay = false
                        scorecardOverlayImage = nil
                        scorecardLoadComplete = false
                        scorecardOverlayScale = 1
                        scorecardOverlayOffset = .zero
                    }

                VStack {
                    HStack {
                        Spacer()
                        Button {
                            showScorecardOverlay = false
                            scorecardOverlayImage = nil
                            scorecardLoadComplete = false
                            scorecardOverlayScale = 1
                            scorecardOverlayOffset = .zero
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding()
                    }
                    Spacer()

                    if let image = scorecardOverlayImage {
                        ScorecardImageView(
                            image: image,
                            scale: $scorecardOverlayScale,
                            offset: $scorecardOverlayOffset
                        )
                    } else if scorecardLoadComplete {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.neutral5)
                            .frame(width: 200, height: 280)
                            .overlay {
                                Text("Scorecard image unavailable")
                                    .fontStyle(kFontName, size: 14, weight: .medium)
                                    .foregroundStyle(Color.neutral2)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.neutral5)
                            .frame(width: 200, height: 280)
                            .overlay {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(palette.foregroundColor)
                                    Text("Loading scorecard…")
                                        .fontStyle(kFontName, size: 14, weight: .medium)
                                        .foregroundStyle(Color.neutral2)
                                }
                            }
                    }

                    Spacer()
                }
            }
        }
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

            NavButton(style: .glass, icon: "e09c", color: palette.foregroundColor) {
                print("fake door for sharing image")
            }
        }
    }

    private var playerHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            PlayerAvatarView(
                initials: participantInitials,
                size: 48,
                glassTint: effectiveAccent.opacity(0.3)
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
                Text("Gross \(totalGross) / Net \(totalNet)")
                    .fontStyle(kFontName, size: 18, weight: .bold)
                    .foregroundStyle(palette.foregroundColor)
            } else {
                Text("Gross \(totalGross)")
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
        let holes = holeNumbers.filter { $0 <= 9 }
        if holes.isPopulated {
            scorecardTile(holes: holes, label: "Out")
        }
    }

    @ViewBuilder
    private var backNineTile: some View {
        let holes = holeNumbers.filter { $0 > 9 }
        if holes.isPopulated {
            scorecardTile(holes: holes, label: "In")
        }
    }

    private func scorecardTile(holes: [Int], label: String) -> some View {
        VStack(spacing: 8) {
            scorecardHeaderRow(holes: holes, label: label)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .background(viewModel.theme.color.opacity(0.6))
            
            scorecardParRow(holes: holes)
                .padding(.horizontal, 16)
            
            scorecardYardsRow(holes: holes)
                .padding(.horizontal, 16)
            
            scorecardHcpRow(holes: holes)
                .padding(.horizontal, 16)
            
            scorecardScoreRow(holes: holes)
                .padding(.horizontal, 16)
            
            if handicapsEnabled {
                scorecardNetRow(holes: holes)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .glassCardEffect(interactive: false)
    }

    private func scorecardHeaderRow(holes: [Int], label: String) -> some View {
        HStack(spacing: 4) {
            Text("Hole")
                .fontStyle(kFontName, size: 11, weight: .bold)
                .foregroundStyle(palette.backgroundColor)
                .frame(width: 36, alignment: .leading)
            ForEach(holes, id: \.self) { h in
                Text("\(h)")
                    .fontStyle(kFontName, size: 11, weight: .bold)
                    .foregroundStyle(palette.backgroundColor)
                    .frame(maxWidth: .infinity)
            }
            Text(label.uppercased())
                .fontStyle(kFontName, size: 11, weight: .bold)
                .foregroundStyle(palette.backgroundColor)
                .frame(width: 36)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .cornerRadius(radius: 6)
    }

    private func scorecardParRow(holes: [Int]) -> some View {
        let values = holes.map { "\(viewModel.hole(for: $0)?.par ?? 0)" }
        let total = holes.reduce(0) { $0 + (viewModel.hole(for: $1)?.par ?? 0) }
        return scorecardValueRow(label: "Par", values: values, total: total)
    }

    private func scorecardYardsRow(holes: [Int]) -> some View {
        let values = holes.map { viewModel.hole(for: $0).map { "\($0.yardage)" } ?? "—" }
        let total = holes.reduce(0) { $0 + (viewModel.hole(for: $1)?.yardage ?? 0) }
        return scorecardValueRow(label: "Yards", values: values, total: total, fontSize: 11)
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
        fontSize: CGFloat = 13,
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

                ZStack {
                    if highlightScores, let strokes {
                        scoreDecoration(par: par, strokes: strokes, color: effectiveAccent)
                    }
                    Text(value)
                        .fontStyle(kFontName, size: fontSize, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            Group {
                if let total {
                    Text("\(total)")
                        .fontStyle(kFontName, size: fontSize, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("")
                        .fontStyle(kFontName, size: fontSize, weight: .medium)
                        .foregroundStyle(Color.neutral2)
                }
            }
            .frame(width: 36)
        }
    }

    @ViewBuilder
    private func scoreDecoration(par: Int, strokes: Int, color: Color) -> some View {
        let diff = strokes - par
        let strokeColor = color

        switch diff {
        case ...(-2):
            Circle()
                .fill(strokeColor)
                .frame(width: 24, height: 24)
        case -1:
            Circle()
                .stroke(strokeColor, lineWidth: 2)
                .frame(width: 24, height: 24)
        case 0:
            EmptyView()
        case 1:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(strokeColor, lineWidth: 2)
                .frame(width: 24, height: 24)
        case 2:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(strokeColor)
                .frame(width: 24, height: 24)
        default:
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(strokeColor)
                    .frame(width: 24, height: 24)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(strokeColor.opacity(0.5), lineWidth: 1)
                    .frame(width: 20, height: 20)
            }
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

    private var courseDateFooter: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = viewModel.snapshot.courseInfo?.name, name.isPopulated {
                Text(name.uppercased())
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Text(viewModel.snapshot.round.lastUpdatedAt.formattedDate)
                .fontStyle(kFontName, size: 13, weight: .medium)
                .foregroundStyle(Color.neutral2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

// MARK: - Scorecard Image Overlay (Pan/Zoom)

private struct ScorecardImageView: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    @State private var currentScale: CGFloat = 1
    @State private var currentOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geom in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale * currentScale)
                .offset(x: offset.width + currentOffset.width, y: offset.height + currentOffset.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentScale = value
                        }
                        .onEnded { value in
                            scale *= value
                            currentScale = 1
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            currentOffset = value.translation
                        }
                        .onEnded { value in
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                            currentOffset = .zero
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            currentScale = 1
                            currentOffset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

private struct SheetedModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(radius: 16)
                .padding(24)
        }
    }
}

private extension View {
    func sheeted() -> some View {
        modifier(SheetedModifier())
    }
}

private func mockPreview(for snapshot: RoundSnapshot) -> some View {
    VStack {
        
    }.sheet(isPresented: .true) {
        IndividualScorecardPreviewContainer(snapshot: snapshot)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }
}

#Preview("Front 9, full scored") {
    mockPreview(for: MockIndividualScorecard.front9Full)
}

#Preview("Back 9, full scored") {
    mockPreview(for: MockIndividualScorecard.back9Full)
}

#Preview("Full 18, full scored") {
    mockPreview(for: MockIndividualScorecard.full18Full)
}

#Preview("Full 18, partially scored") {
    mockPreview(for: MockIndividualScorecard.full18Partial)
}

#Preview("Full 18, dark") {
    mockPreview(for: MockIndividualScorecard.full18Full)
}

#Preview("Full 18, gross/net") {
    mockPreview(for: MockIndividualScorecard.full18WithHandicaps)
}

#Preview("Full 18, attached scorecard") {
    mockPreview(for: MockIndividualScorecard.full18WithAttachedScorecard)
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
