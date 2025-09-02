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
    
    var holeCount: Int {
        switch self {
        case .full18:                 return 18
        case .front9, .back9:         return 9
        case .custom(let lo, let hi):
            precondition(lo >= 1 && hi >= lo && hi <= 18, "Invalid custom hole range")
            return hi - lo + 1
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

extension HoleSegment {
    
    // Initialize from HoleRange struct
    init(range: HoleRange) {
        switch (range.startHole, range.endHole) {
        case (1, 18):
            self = .full18
        case (1, 9):
            self = .front9
        case (10, 18):
            self = .back9
        default:
            self = .custom(lower: range.startHole, upper: range.endHole)
        }
    }
    
    // Convert to HoleRange struct
    func toHoleRange(totalHoles: Int = 18) -> HoleRange? {
        guard let bounds = holeNumberBounds(totalHoles: totalHoles) else { return nil }
        return HoleRange(startHole: bounds.lowerBound, endHole: bounds.upperBound)
    }
    
    // Direct conversion without totalHoles check (when you know it's valid)
    var holeRange: HoleRange {
        switch self {
        case .full18:
            return HoleRange(startHole: 1, endHole: 18)
        case .front9:
            return HoleRange(startHole: 1, endHole: 9)
        case .back9:
            return HoleRange(startHole: 10, endHole: 18)
        case .custom(let lower, let upper):
            return HoleRange(startHole: lower, endHole: upper)
        }
    }
}

// MARK: - Codable
extension HoleSegment: Codable {
    enum CodingKeys: String, CodingKey {
        case type, lower, upper
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "full18":
            self = .full18
        case "front9":
            self = .front9
        case "back9":
            self = .back9
        case "custom":
            let lower = try container.decode(Int.self, forKey: .lower)
            let upper = try container.decode(Int.self, forKey: .upper)
            self = .custom(lower: lower, upper: upper)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown hole segment type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .full18:
            try container.encode("full18", forKey: .type)
        case .front9:
            try container.encode("front9", forKey: .type)
        case .back9:
            try container.encode("back9", forKey: .type)
        case .custom(let lower, let upper):
            try container.encode("custom", forKey: .type)
            try container.encode(lower, forKey: .lower)
            try container.encode(upper, forKey: .upper)
        }
    }
}
