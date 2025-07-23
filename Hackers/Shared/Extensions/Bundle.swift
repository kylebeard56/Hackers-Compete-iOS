//
//  Bundle.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import UIKit

extension Bundle {
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    @MainActor
    var osVersion: String {
        return UIDevice.current.systemVersion
    }
}

