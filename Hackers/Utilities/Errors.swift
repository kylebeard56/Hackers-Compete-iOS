//
//  Errors.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation

enum HackersError: Error {
    case documentNotFound
    case redrawFailed
    case unknownSnapshotError
}

extension HackersError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .documentNotFound:         return "Firebase document not found"
        case .redrawFailed:             return "Card couldn't be redrawn"
        case .unknownSnapshotError:     return "Firebase snapshot error - unknown source"
        }
    }
}
