//
//  ShareRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/2/25.
//

import AlertToast
import CoreImage.CIFilterBuiltins
import SwiftUI

struct ShareRoundView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var snapshot: RoundSnapshot
    
    private var link: String { kAppLink + "/join?round_id=\(snapshot.round.shareCode)" }
    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }
    
    private var courseName: String? { snapshot.round.configuration.courses.first?.courseInfo.name }
    
    private let subtitlePrefix = "Scan or share the code below to join your round"
    private var qrSize: CGFloat { UIScreen.main.bounds.size.width * 0.69 }
    
    @State private var showClipboardToast = false
    
    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                Text("Share round")
                    .fontStyle(.poppins, size: 24, weight: .semibold)
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
            
            Text("\(subtitlePrefix)\(courseName.map { " at \($0)" } ?? "").")
                .fontStyle(.poppins, size: 15, weight: .regular)
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
                    "Join round\(courseName.map { "at \($0)" } ?? "")",
                    image: Image("AppIcon-V3")
                )) {
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
    }
    
    private var shareLinkButton: some View {
        VStack(spacing: 8) {
            Text("\(snapshot.round.shareCode.slashZeros())")
                .fontStyle(.system, size: 40, weight: .semibold, design: .monospaced)
            
            Text("Tap to copy share code")
                .fontStyle(.poppins, size: 15, weight: .regular)
        }
        .alignCenter()
        .foregroundStyle(Color.accentGreen)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.accentGreen.opacity(colorScheme.translucent))
        .cornerRadius(radius: 12)
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
            // TODO: Error icon
        }
    }

    // TODO: QR code styling
    /// https://github.com/dagronf/QRCode
    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        
        guard let outputImage = filter.outputImage else { return nil }

        // Scale the QR code up to a readable size
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}


#Preview {
    ZStack {}.sheet(isPresented: .true) {
        ShareRoundView(snapshot: .mock())
            .presentationDragIndicator(.visible)
    }
    
}
