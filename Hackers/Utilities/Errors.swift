//
//  Errors.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation

enum HackersError: Error {
    case documentNotFound
}

extension HackersError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .documentNotFound:    return "Firebase document not found"
        }
    }
}
