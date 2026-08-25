//
//  Double.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/25.
//

import Foundation

extension Double {
    func clamped01() -> Double { max(0, min(1, self)) }
}
