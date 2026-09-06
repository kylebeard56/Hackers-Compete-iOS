//
//  UIImage+Base64.swift
//  Hackers
//
//  Base64 encoding for vision API requests (matches Box Fox pattern).
//

import UIKit

extension UIImage {
    /// JPEG base64 string for LLM vision APIs.
    ///
    /// Camera images can be 12-48 MP. Encoding them at their original size briefly keeps
    /// the decoded bitmap, JPEG data, and base64 string in memory together. Bound the long
    /// edge before encoding so scorecard scans remain stable on memory-constrained devices.
    var base64: String? {
        let maximumDimension: CGFloat = 2_048
        let longestDimension = max(size.width, size.height)
        let preparedImage: UIImage

        if longestDimension > maximumDimension {
            let ratio = maximumDimension / longestDimension
            let targetSize = CGSize(
                width: max(1, floor(size.width * ratio)),
                height: max(1, floor(size.height * ratio))
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            preparedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                draw(in: CGRect(origin: .zero, size: targetSize))
            }
        } else {
            preparedImage = self
        }

        return autoreleasepool {
            preparedImage.jpegData(compressionQuality: 0.7)?.base64EncodedString()
        }
    }
}
