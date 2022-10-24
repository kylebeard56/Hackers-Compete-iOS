//
//  Errors.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation

enum HackersError: Error {
    case something
}

extension HackersError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .something:    return "todo: add description here"
        }
    }
}
