//
//  Identify.swift
//  Hackers
//
//  Created by Kyle Beard on 1/4/26.
//

import SwiftUI

/// Generic wrapper to make a primitive data type conform to `Identifable`
struct Identify<T>: Identifiable {
    var id = UUID()
    private(set) var value: T
    
    init(value: T) {
        self.id = UUID()
        self.value = value
    }
}
