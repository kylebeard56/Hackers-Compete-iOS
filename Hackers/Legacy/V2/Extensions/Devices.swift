//
//  Devices.swift
//  Hackers
//
//  Created by Kyle Beard on 4/8/23.
//

//import Devices
//import Foundation
//import UIKit
//
//public extension UIDevice {
//    /// Returns TRUE if device point height is less than or equal to 736 (iPhone 6/7/8, 6/7/8 Plus or SE)
//    /// https://developer.apple.com/design/human-interface-guidelines/ios/visual-design/adaptivity-and-layout/
//    static var isSmall: Bool {
//        return UIScreen.main.bounds.size.height <= 736
//    }
//
//    /// Returns TRUE if the safe area insets at the bottom are greater than zero.
//    static var hasNotch: Bool {
//        return UIDevice.modelName.contains("iPhone X")
//            || UIDevice.modelName.contains("iPhone 11")
//            || UIDevice.modelName.contains("iPhone 12")
//            || UIDevice.modelName.contains("iPhone 13")
//            || UIDevice.modelName.contains("iPhone 14")
//            || UIDevice.modelName.contains("iPhone 15")
//            || UIDevice.modelName.contains("iPhone 16")
//            || UIDevice.modelName.contains("iPhone 17")
//            || UIDevice.modelName.contains("iPhone 18")
//            || UIDevice.modelName.contains("iPhone 19")
//            || UIDevice.modelName.contains("iPhone 20")
//    }
//
//    /// https://www.theiphonewiki.com/wiki/Models
//    /// https://github.com/ptrkstr/Devices
//    static let modelName: String = {
//        var systemInfo = utsname()
//        uname(&systemInfo)
//        let machineMirror = Mirror(reflecting: systemInfo.machine)
//        let identifier =  machineMirror.children.reduce("") { identifier, element in
//            guard let value = element.value as? Int8, value != 0 else { return identifier }
//            return identifier + String(UnicodeScalar(UInt8(value)))
//        }
//
//        let device = iPhone.all.first { $0.identifier == identifier }
//        return "\(device?.generation ?? "N/A") - \(device?.storage ?? "N/A")"
//    }()
//}
//
