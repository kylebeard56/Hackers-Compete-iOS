//
//  CompleteRoundSheet.swift
//  Hackers
//
//  Created by Kyle Beard on 3/3/26.
//

import PhotosUI
import SwiftUI

struct CompleteRoundSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession

    @ObservedObject var viewModel: LiveRoundViewModel

    var snapshot: RoundSnapshot { roundSession.snapshot }
    var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    // MARK: - State

    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showMaxScoreAlert = false
    @State private var isSubmitting = false

    // MARK: - Derived

    private var unscoredHoles: [Int] { viewModel.unscoredHoleNumbers }
    private var hasUnscoredHoles: Bool { unscoredHoles.isPopulated }
    private var maxScoreRule: MaxScoreOverPar {
        snapshot.gameFormat.configuration.maxScoreOverPar
    }
    private var maxScoreDisplayName: String { maxScoreRule.displayName }
    private var unscoredHoleLabel: String {
        unscoredHoles.map { "Hole \($0)" }.joined(separator: ", ")
    }
    private var currentParticipant: RoundParticipant? {
        guard let id = viewModel.currentParticipantID else { return nil }
        return snapshot.participants.first(where: { $0.id == id })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            BackgroundTheme(palette: palette, theme: viewModel.theme)

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
                selectedImage = image
                showPhotoPicker = false
            }
        }
        .alert("Give max score to each?", isPresented: $showMaxScoreAlert) {
            Button("Give \(maxScoreDisplayName)", role: .none) {
                Task { await viewModel.applyMaxScoresToUnscoredHoles() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These scores will be given \(maxScoreDisplayName).")
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Complete round?")
                    .fontStyle(kFontName, size: 22, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.fire(.light)
                dismiss()
            } label: {
                Icon(name: "f00d", size: 16, weight: .solid)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Subtitle

    private var subtitle: some View {
        Text("Sign your scorecard to finish this round.")
            .fontStyle(kFontName, size: 16, weight: .regular)
            .foregroundStyle(Color.neutral)
            .alignLeading()
    }

    // MARK: - Missing Scores Banner

    private var missingScoresBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("You're missing scores.")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(.white)

                Text("It looks like the following holes have 1 or more players unscored:")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(.white.opacity(0.85))

                Text(unscoredHoleLabel)
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(.white)
            }

            Button {
                Haptics.fire(.light)
                showMaxScoreAlert = true
            } label: {
                Text("Mark as max score")
                    .fontStyle(kFontName, size: 14, weight: .semibold)
                    .foregroundStyle(.white)
                    .alignCenter()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15))
                    .cornerRadius(radius: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    )
            }
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

    private var photoUploadButton: some View {
        Button {
            Haptics.fire(.light)
            showPhotoPicker = true
        } label: {
            VStack(spacing: 12) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(radius: 12)
                } else {
                    VStack(spacing: 8) {
                        Icon(name: "f030", size: 28, weight: .regular)
                            .foregroundStyle(Color.neutral)
                        Text("Upload photo of scorecard")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(Color.neutral)
                        Text("Tap to choose from your library")
                            .fontStyle(kFontName, size: 13, weight: .regular)
                            .foregroundStyle(Color.neutral3)
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(selectedImage == nil ? 0 : 0)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        selectedImage != nil ? Color.accentYellow.opacity(0.5) : Color.neutral3,
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
    }

    // MARK: - CTA Footer

    private var ctaFooter: some View {
        GlassButton(
            title: "Sign scorecard",
            tintColor: .accentYellow,
            isDisabled: .constant(selectedImage == nil),
            isLoading: .constant(isSubmitting),
            onTap: { Task { await submitCompletion() } }
        )
    }

    // MARK: - Submit

    private func submitCompletion() async {
        guard let image = selectedImage else { return }
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else { return }

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

        do {
            let asset = try await FirebaseService.shared.uploadScorecard(
                imageData: jpegData,
                roundID: roundID,
                playerID: playerID
            )

            let entry = CompletedPlayer(
                playerID: playerID,
                playerDisplayName: displayName,
                completedAt: .init(),
                type: .signedScorecard,
                scorecardStorageID: asset
            )

            try await FirebaseService.shared.markPlayerComplete(
                roundID: roundID,
                completedPlayer: entry
            )

            dismiss()
            appSession.routeTo(.dashboard)
        } catch {
            isSubmitting = false
        }
    }
}

// MARK: - Scorecard Photo Picker

private struct ScoreCardPhotoPicker: UIViewControllerRepresentable {
    var onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(onImageSelected: onImageSelected) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        init(onImageSelected: @escaping (UIImage) -> Void) {
            self.onImageSelected = onImageSelected
        }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { self?.onImageSelected(image) }
            }
        }
    }
}
