//
//  ScorecardScanView.swift
//  Hackers
//
//  Camera + photo picker for OCR scorecard scanning.
//

import PhotosUI
import SwiftUI
import UIKit

struct ScorecardScanView: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    var onCourseExtracted: (Course) -> Void

    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var isScanning = false
    @State private var errorMessage: String?

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                palette.backgroundColor.ignoresSafeArea()

                VStack(spacing: 24) {
                    if let image = selectedImage {
                        imagePreview(image)
                    } else {
                        pickerPrompt
                    }

                    if isScanning {
                        ProgressView("Scanning scorecard…")
                            .padding()
                    }

                    if let msg = errorMessage {
                        Text(msg)
                            .fontStyle(kFontName, size: 14, weight: .medium)
                            .foregroundStyle(Color.systemError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Scan Scorecard")
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                ScorecardPhotoPicker { image in
                    selectedImage = image
                    showPhotoPicker = false
                    errorMessage = nil
                    Task { await scanImage(image) }
                }
            }
            .sheet(isPresented: $showCamera) {
                ScorecardImagePicker(
                    sourceType: .camera,
                    onImageSelected: { image in
                        selectedImage = image
                        showCamera = false
                        errorMessage = nil
                        Task { await scanImage(image) }
                    },
                    onCancel: { showCamera = false }
                )
            }
        }
    }

    private var pickerPrompt: some View {
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
            VStack(spacing: 12) {
                Icon(name: "f03e", size: 40, weight: .regular)
                    .foregroundStyle(Color.neutral)
                Text("Scan a scorecard")
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                Text("Take a photo or choose from your library")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
        }
        .menuStyle(.borderlessButton)
        .background(Color.neutral6)
        .cornerRadius(radius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.neutral3, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }

    private func imagePreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .cornerRadius(radius: 12)
                .clipped()

            Button {
                selectedImage = nil
                errorMessage = nil
            } label: {
                Text("Choose different photo")
                    .fontStyle(kFontName, size: 14, weight: .medium)
                    .foregroundStyle(Color.accentGreen)
            }
        }
    }

    private func scanImage(_ image: UIImage) async {
        addBreadcrumb()
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }

        do {
            let course = try await CourseScorecardOCRService.shared.extractCourse(from: image)
            printPretty(course)
            await MainActor.run {
                onCourseExtracted(course)
                dismiss()
            }
        } catch CourseScorecardOCRError.apiKeyMissing {
            let provider = AIModelConfig.defaultForVision.provider
            let keyName = provider == .anthropic ? "ANTHROPIC_API_KEY" : "OPENAI_API_KEY"
            addBreadcrumb(level: .error, message: "Failed to read scorecard: \(keyName) missing")
        } catch CourseScorecardOCRError.decodingFailed(let msg) {
            addBreadcrumb(level: .error, message: "Failed to read scorecard: \(msg)")
        } catch let error {
            addBreadcrumb(level: .error, message: "Failed to scan scorecard", error: error)
        }
    }
}

// MARK: - Photo Picker

private struct ScorecardPhotoPicker: UIViewControllerRepresentable {
    var onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

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

// MARK: - Camera Picker

private struct ScorecardImagePicker: UIViewControllerRepresentable {
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
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCancel()
        }
    }
}
