//
//  Optional.swift
//  Hackers
//
//  Created by Kyle Beard on 9/12/25.
//

import Foundation

extension Optional {
    var exists: Bool { self != nil }
    var doesNotExist: Bool { self == nil }
}
