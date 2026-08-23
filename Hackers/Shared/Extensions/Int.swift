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
    
    var isEven: Bool {
        self % 2 == 0
    }
    
    var isOdd: Bool {
        self % 2 == 1
    }
}
