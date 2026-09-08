//
//  CompleteRoundSheet.swift
//  Hackers
//
//  Created by Kyle Beard on 3/3/26.
//

import PhotosUI
import SwiftUI
import UIKit

struct CompleteRoundSheet: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession

    @ObservedObject var viewModel: LiveRoundViewModel

    var snapshot: RoundSnapshot { roundSession.snapshot }

    init(viewModel: LiveRoundViewModel, previewSelectedImage: UIImage? = nil) {
        self.viewModel = viewModel
        _selectedImage = State(initialValue: previewSelectedImage)
    }
    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    // MARK: - State

    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var showMaxScoreAlert = false
    @State private var isSubmitting = false
    @State private var didTrackCompletionOpened = false

    // MARK: - Derived

    private var unscoredHoles: [Int] { viewModel.unscoredHoleNumbers }
    private var hasUnscoredHoles: Bool { unscoredHoles.isPopulated }
    private var maxScoreRule: MaxScoreOverPar {
        snapshot.gameFormat.configuration.maxScoreOverPar
    }
    private var maxScoreDisplayName: String { maxScoreRule.displayName }
//    private var unscoredHoleLabel: String {
//        unscoredHoles.map { "\($0)" }.joined(separator: ", ")
//    }
    private var unscoredHoleLabel: String {
        guard !unscoredHoles.isEmpty else { return "" }
        
        let sorted = unscoredHoles.sorted()
        var ranges: [String] = []
        
        var start = sorted[0]
        var previous = sorted[0]
        
        for hole in sorted.dropFirst() {
            if hole == previous + 1 {
                // Continue the run
                previous = hole
            } else {
                // End the current run
                if start == previous {
                    ranges.append("\(start)")
                } else {
                    ranges.append("\(start) thru \(previous)")
                }
                
                start = hole
                previous = hole
            }
        }
        
        // Append the final run
        if start == previous {
            ranges.append("\(start)")
        } else {
            ranges.append("\(start) thru \(previous)")
        }
        
        return ranges.joined(separator: ", ")
    }
    
    private var currentParticipant: RoundParticipant? {
        guard let id = viewModel.currentParticipantID else { return nil }
        return snapshot.participants.first(where: { $0.id == id })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            //BackgroundTheme(palette: palette, theme: viewModel.theme)
            palette.backgroundColor.edgesIgnoringSafeArea(.bottom)

            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        subtitle
                            .padding(.horizontal, 20)

                        if hasUnscoredHoles {
                            missingScoresBanner
                                .padding(.horizontal, 20)
                        }

                        photoUploadButton
                            .padding(.horizontal, 20)

                        Padding(.vertical, 8)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }

                ctaFooter
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPhotoPicker) {
            ScoreCardPhotoPicker { image in
                if let image { selectedImage = image }
                showPhotoPicker = false
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera, onImageSelected: { image in
                selectedImage = image
                showCamera = false
            }, onCancel: { showCamera = false })
        }
        .alert("Give max score to each?", isPresented: $showMaxScoreAlert) {
            Button("Give \(maxScoreDisplayName)", role: .none) {
                Task { await viewModel.applyMaxScoresToUnscoredHoles() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These scores will be given \(maxScoreDisplayName).")
        }
        .onAppear(perform: trackRoundCompletionOpenedIfNeeded)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Complete round?")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            Spacer(minLength: 0)
            NavButton(style: .glass) {
                dismiss()
            }
//            Button {
//                Haptics.fire(.light)
//                dismiss()
//            } label: {
//                Icon(name: "f00d", size: 16, weight: .solid)
//                    .foregroundStyle(palette.foregroundColor)
//                    .frame(width: 36, height: 36)
//                    .background(.ultraThinMaterial)
//                    .clipShape(Circle())
//            }
        }
    }

    // MARK: - Subtitle

    private var subtitle: some View {
        Text("Sign your scorecard to finish this round and confirm your score entries are accurate.")
            .fontStyle(kFontName, size: 15, weight: .regular)
            .foregroundStyle(Color.neutral)
            .multilineTextAlignment(.leading)
            .alignLeading()
    }

    // MARK: - Missing Scores Banner

    private var missingScoresBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("You're missing scores.")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(Color.systemError)

                Text("It looks like the following holes are incomplete:")
                    .fontStyle(kFontName, size: 13, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)

                Text(unscoredHoleLabel)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()
            }

            Button {
                guard !viewModel.isApplyingMaxScores else { return }
                Haptics.fire(.light)
                showMaxScoreAlert = true
            } label: {
                Text(viewModel.isApplyingMaxScores ? "Applying..." : "Mark as max score")
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCardEffect(cornerRadius: 10, tint: palette.backgroundColor.opacity(0.6))
            }
            .disabled(viewModel.isApplyingMaxScores)
        }
        .padding(16)
        .background(Color.systemError.opacity(colorScheme.translucent))
        .cornerRadius(radius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.systemError.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Photo Upload Button

    @ViewBuilder
    private var photoUploadButton: some View {
        Group {
            if let image = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(radius: 12)
                    
                    NavButton(style: .glass, size: 16) {
                        selectedImage = nil
                    }
                    .padding(8)
                }
            } else {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            Haptics.fire(.light)
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                    Button {
                        Haptics.fire(.light)
                        showPhotoPicker = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle.angled")
                    }
                } label: {
                    VStack(spacing: 8) {
                        Icon(name: "f030", size: 28, weight: .regular)
                            .foregroundStyle(Color.neutral)
                        Text("Upload photo of scorecard")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(Color.neutral)
                        Text("Tap to take a photo or choose from library")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral2)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .background(Color.neutral6)
        .cornerRadius(radius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    selectedImage != nil ? Color.accentYellow.opacity(0.5) : Color.neutral3,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
    }

    // MARK: - CTA Footer

    private var ctaFooter: some View {
        let isBusy = isSubmitting || viewModel.isApplyingMaxScores
        return GlassButton(
            title: "Sign scorecard",
            labelColor: palette.foregroundColor,
            tintColor: hasUnscoredHoles ? Color.systemError : Color.accentYellow,
            isDisabled: .false,
            isLoading: $isSubmitting,
            onTap: { Task { await submitCompletion() } }
        )
    }

    // MARK: - Submit

    private func submitCompletion() async {
        addBreadcrumb()
        isSubmitting = true
        defer { isSubmitting = false }

        let roundID = snapshot.round.id
        let participant = currentParticipant
        let playerID: String
        if let pid = participant?.playerID {
            playerID = pid
        } else {
            playerID = await AppData.shared.getPrimaryPlayer()?.id ?? ""
        }
        let displayName = participant?.name.fullName

        var asset: StorageAsset? = nil
        if let selectedImage,
           let jpegData = selectedImage.jpegData(compressionQuality: FirebaseService.scorecardCompressionQuality) {
            do {
                asset = try await FirebaseService.shared.uploadScorecard(
                    imageData: jpegData,
                    roundID: roundID,
                    playerID: playerID
                )
            } catch {
                isSubmitting = false
                Haptics.fire(.error)
                return  // or handle error
            }
        }

        let entry = CompletedPlayer(
            playerID: playerID,
            playerDisplayName: displayName,
            completedAt: .init(),
            type: .signedScorecard,
            scorecardStorageID: asset
        )

        do {
            try await FirebaseService.shared.markPlayerComplete(
                roundID: roundID,
                completedPlayer: entry
            )
            addEvent(
                "round.completed",
                eventProps: viewModel.roundCompletionTelemetryProps(
                    extra: [
                        "round_id": roundID,
                        "player_id": playerID,
                        "signed_scorecard": true
                    ]
                )
            )
            appSession.clearRoundResume()
            dismiss()
            appSession.path.removeLast(appSession.path.count)
            appSession.routeTo(.dashboard)
        } catch {
            Haptics.fire(.error)
            isSubmitting = false
        }
    }

    private func trackRoundCompletionOpenedIfNeeded() {
        guard !didTrackCompletionOpened else { return }
        didTrackCompletionOpened = true
        addEvent(
            "live_round.round_completion_opened",
            eventProps: viewModel.roundCompletionTelemetryProps(
                extra: [
                    "has_unscored_holes": hasUnscoredHoles
                ]
            )
        )
    }
}

// MARK: - Preview

#Preview("With unscored holes") {
    BackgroundTheme(palette: .init(theme: .glass, scheme: .light), theme: .purple)
        .sheet(isPresented: .true) {
            CompleteRoundSheetPreview(
                snapshot: CompleteRoundSheetPreview.snapshotWithUnscoredHoles
            )
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(500)])
        }
}

#Preview("All holes scored") {
    BackgroundTheme(palette: .init(theme: .glass, scheme: .light), theme: .purple)
        .sheet(isPresented: .true) {
            CompleteRoundSheetPreview(
                snapshot: CompleteRoundSheetPreview.snapshotAllScored
            )
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(500)])
        }
}

#Preview("With attached scorecard") {
    BackgroundTheme(palette: .init(theme: .glass, scheme: .light), theme: .purple)
        .sheet(isPresented: .true) {
            CompleteRoundSheetPreview(
                snapshot: CompleteRoundSheetPreview.snapshotAllScored,
                selectedImage: UIImage(named: "MockScorecard")
            )
            .presentationDragIndicator(.visible)
            .presentationDetents([.height(500)])
        }
}

@MainActor
private struct CompleteRoundSheetPreview: View {
    let snapshot: RoundSnapshot
    var selectedImage: UIImage?

    @StateObject private var appSession: AppSession
    @StateObject private var roundSession: RoundSession
    @StateObject private var viewModel: LiveRoundViewModel

    init(snapshot: RoundSnapshot, selectedImage: UIImage? = nil) {
        self.snapshot = snapshot
        self.selectedImage = selectedImage
        let session = AppSession()
        session.ephemeralParticipantID = snapshot.participants.first?.id
        _appSession = StateObject(wrappedValue: session)

        let rs = RoundSession()
        rs.snapshot = snapshot
        _roundSession = StateObject(wrappedValue: rs)

        let vm = LiveRoundViewModel()
        vm.set(snapshot: snapshot)
        vm.bind(appSession: session, roundSession: rs)
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some View {
        CompleteRoundSheet(viewModel: viewModel, previewSelectedImage: selectedImage)
            .environmentObject(appSession)
            .environmentObject(roundSession)
    }

    static var snapshotWithUnscoredHoles: RoundSnapshot {
        var s = MockLiveRound2v2.snapshot
        s.segments = [segmentForParticipants(s.participants)]
        return s
    }

    static var snapshotAllScored: RoundSnapshot {
        var s = snapshotWithUnscoredHoles
        s.scoring = (1...18).flatMap { hole in
            s.participants.map { p in
                ScoreEntry(
                    id: "h\(hole)_s1_\(p.id)",
                    holeNumber: hole,
                    segmentID: "seg1",
                    groupID: p.groupID ?? "",
                    scoringUnitID: p.id,
                    participantIDs: [p.id],
                    strokes: 4,
                    value: nil,
                    pickedUp: false,
                    entryID: p.id,
                    createdAt: .init(),
                    lastUpdatedAt: .init(),
                    parentID: s.round.id
                )
            }
        }
        return s
    }

    private static func segmentForParticipants(_ participants: [RoundParticipant]) -> RoundSegment {
        .init(
            id: "seg1",
            roundID: MockLiveRound2v2.roundID,
            holeRange: .init(startHole: 1, endHole: 18),
            gameFormat: .strokePlay,
            scoringUnits: participants.map {
                ScoringUnit(
                    id: $0.id,
                    owner: .participant,
                    ownerIDs: [$0.id],
                    scoringMethod: .individual
                )
            },
            createdAt: .init(),
            lastUpdatedAt: .init(),
            parentID: MockLiveRound2v2.roundID
        )
    }
}

// MARK: - Image Picker (Camera)

private struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onImageSelected: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImageSelected: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImageSelected = onImageSelected
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

// MARK: - Scorecard Photo Picker

private struct ScoreCardPhotoPicker: UIViewControllerRepresentable {
    /// Called on the main queue when picking ends. `nil` means cancel or failed load.
    var onFinished: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(onFinished: onFinished) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onFinished: (UIImage?) -> Void
        init(onFinished: @escaping (UIImage?) -> Void) {
            self.onFinished = onFinished
        }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                DispatchQueue.main.async { [weak self] in self?.onFinished(nil) }
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                let image = object as? UIImage
                DispatchQueue.main.async { self?.onFinished(image) }
            }
        }
    }
}
