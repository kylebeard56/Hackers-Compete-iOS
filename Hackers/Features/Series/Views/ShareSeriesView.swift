//
//  ShareSeriesView.swift
//  Hackers
//

import AlertToast
import CoreImage.CIFilterBuiltins
import SwiftUI

struct ShareSeriesView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: SeriesViewModel

    private var joinToken: String {
        let code = viewModel.series.shareCode
        if code.isPopulated { return code }
        return viewModel.series.id
    }

    private var link: String { kDeepLink + "/join?series_id=\(joinToken)" }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var qrSize: CGFloat { UIScreen.main.bounds.size.width * 0.69 }

    @State private var showClipboardToast = false

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Text(viewModel.series.experiencePreset.shareSheetTitle)
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignCenter()

                NavButton(
                    icon: "f00d",
                    color: palette.foregroundColor,
                    theme: palette.theme,
                    onTap: { dismiss() }
                )
                .alignTrailing()
            }

            Text("Scan or share the code below so players can join \(viewModel.series.name.isEmpty ? viewModel.series.experiencePreset.shareInviteJoinPhrase : viewModel.series.name).")
                .fontStyle(kFontName, size: 15, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
                .alignCenter()

            Spacer(minLength: 0)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: palette.foregroundColor.opacity(0.12), radius: 12, x: 0, y: 4)

                QRCode(link: link)
                    .padding(10)
            }
            .frame(width: qrSize, height: qrSize)

            Spacer(minLength: 0)

            if let url = URL(string: link) {
                ShareLink(
                    item: url,
                    preview: SharePreview(
                        "Join \(viewModel.series.name.isEmpty ? viewModel.series.experiencePreset.shareJoinPreviewFallbackNoun : viewModel.series.name)",
                        image: Image("AppIcon-V3")
                    )
                ) {
                    shareLinkButton
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        Haptics.fire(.light)
                    }
                )
            } else {
                Button(action: {
                    Haptics.fire(.light)
                    UIPasteboard.general.string = link
                    showClipboardToast = true
                }) {
                    shareLinkButton
                }
            }
        }
        .padding(16)
        .background(palette.backgroundColor)
        .toast(isPresenting: $showClipboardToast) { .completeTile("Share link copied to clipboard") }
        .task {
            await viewModel.ensureShareCodeIfNeeded()
        }
    }

    private var shareLinkButton: some View {
        VStack(spacing: 8) {
            Text("\(joinToken.slashZeros())")
                .fontStyle(.system, size: 40, weight: .semibold, design: .monospaced)

            Text("Tap to copy share code")
                .fontStyle(kFontName, size: 15, weight: .regular)
        }
        .alignCenter()
        .foregroundStyle(Color.accentGreen)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.accentGreen.opacity(colorScheme.translucent))
        .cornerRadius(radius: 12)
    }
}

#Preview {
    ZStack { }.sheet(isPresented: .constant(true)) {
        ShareSeriesView(viewModel: SeriesViewModel())
            .presentationDragIndicator(.visible)
    }
}

fileprivate struct QRCode: View {
    var link: String

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = generateQRCode(from: link) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text("Invalid QR")
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)

        guard let outputImage = filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
