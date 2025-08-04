//
//  Int.swift
//  Hackers
//
//  Created by Kyle Beard on 8/4/25.
//

import Foundation
import UIKit

extension Int {
    var pluralized: String {
        self > 1 ? "s" : ""
    }
}
