//
//  Float.swift
//  Hackers
//
//  Created by Kyle Beard on 2/18/23.
//

import Foundation

extension CGFloat {
    var toGolfDiff: String {
        if self > 0 {
            return "+\(self.twoDigits)"
        } else if self < 0 {
            return "-\(self.twoDigits)"
        } else {
            return "+\(self.twoDigits)"
        }
    }
    
    var twoDigits: CGFloat {
        return (self * 100).rounded(.toNearestOrEven) / 100
    }
}
