//
//  HoleSegment.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/25.
//

import Foundation

/// Segment of a course expressed as 1-based inclusive hole bounds, with conveniences for common cases.
enum HoleSegment: Hashable, Equatable {
    case full18
    case front9
    case back9
    case custom(lower: Int, upper: Int)   // 1-based inclusive

    var title: String {
        switch self {
        case .full18:                   return "Full 18"
        case .front9:                   return "Front 9"
        case .back9:                    return "Back 9"
        case .custom(let lo, let hi):   return lo == 1 ? "\(hi) holes" : "Holes \(lo)–\(hi)"
        }
    }
    
    /// Convenience for "first N holes"
    static func custom(count: Int) -> HoleSegment {
        .custom(lower: 1, upper: count)
    }

    /// 1-based (inclusive) hole-number bounds, clamped to the available holes.
    func holeNumberBounds(totalHoles: Int) -> ClosedRange<Int>? {
        guard totalHoles > 0 else { return nil }
        switch self {
        case .full18:
            let hi = min(18, totalHoles)
            return hi >= 1 ? 1...hi : nil
        case .front9:
            let hi = min(9, totalHoles)
            return hi >= 1 ? 1...hi : nil
        case .back9:
            guard totalHoles >= 10 else { return nil }
            return 10...min(18, totalHoles)
        case .custom(let lo, let hi):
            guard lo <= hi else { return nil }
            let clampedLo = max(1, min(lo, totalHoles))
            let clampedHi = max(1, min(hi, totalHoles))
            guard clampedLo <= clampedHi else { return nil }
            return clampedLo...clampedHi
        }
    }

    /// 0-based (half-open) index bounds suitable for slicing arrays.
    func indexBounds(totalHoles: Int) -> Range<Int>? {
        guard let nb = holeNumberBounds(totalHoles: totalHoles) else { return nil }
        // convert 1-based inclusive [lo...hi] → 0-based half-open [lo-1 ..< hi]
        return (nb.lowerBound - 1)..<nb.upperBound
    }
}
