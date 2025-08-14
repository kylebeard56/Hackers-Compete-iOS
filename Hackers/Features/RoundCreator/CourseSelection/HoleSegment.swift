//
//  HoleSegment.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/25.
//

import Foundation

enum HoleSegment: Hashable, Identifiable {
    case front9
    case back9
    case full18
    case custom(count: Int)   // e.g. 12-hole par-3 course

    var id: String {
        switch self {
        case .front9:           return "front9"
        case .back9:            return "back9"
        case .full18:           return "full18"
        case .custom(let c):    return "custom\(c)"
        }
    }

    var title: String {
        switch self {
        case .front9:           return "Front 9"
        case .back9:            return "Back 9"
        case .full18:           return "Full 18"
        case .custom(let c):    return "\(c) holes"
        }
    }

    /// Zero-based hole indices for filtering a card/score view.
    var holeRange: Range<Int> {
        switch self {
        case .front9:           return 0..<9
        case .back9:            return 9..<18
        case .full18:           return 0..<18
        case .custom(let c):    return 0..<max(0, c)
        }
    }
}
