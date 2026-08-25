//
//  UIImage+Base64.swift
//  Hackers
//
//  Base64 encoding for vision API requests (matches Box Fox pattern).
//

import UIKit

extension UIImage {
    /// JPEG base64 string for LLM vision APIs. Uses 0.7 compression for consistency with Box Fox.
    var base64: String? {
        jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }
}
