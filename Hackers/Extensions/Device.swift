//
//  Device.swift
//  Hackers
//
//  Created by Kyle Beard on 4/10/23.
//

import Foundation
import UIKit

extension UIScreen {
    /// Returns TRUE if device height is LTE 736 (iPhone 6/7/8, 6/7/8 Plus or SE any generation).
    /// https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
    static var isSmall: Bool {
        return UIScreen.main.bounds.size.height <= 736
    }
}

extension UIDevice { }
