//
//  Array.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import UIKit

extension Array where Element: Hashable {
    /// Return the symmetric different between two array.
    func difference(from other: [Element]) -> [Element] {
        let thisSet = Set(self)
        let otherSet = Set(other)
        return Array(thisSet.symmetricDifference(otherSet))
    }
    
    /// Construct array of unique elements only, preserving order.
    var orderedUniques: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
    
    var checksum: Int {
        if let d = try? JSONSerialization.data(withJSONObject: self, options: []) {
            return d.checksum
        } else {
            return 0
        }
    }
}

extension Array where Element: Equatable {
    /// Construct array of unique elements only.
    var uniques: [Element] {
        var uniqueValues: [Element] = []
        forEach { item in
            guard !uniqueValues.contains(item) else { return }
            uniqueValues.append(item)
        }
        return uniqueValues
    }
    
    /// Will remove item from array if already in, otherwise will append.
    mutating func toggle(_ item: Element) {
        if self.contains(item) {
            self.removeAll(where: { $0 == item })
        } else {
            self.append(item)
        }
    }
    
    /// Will add an item to an array if it is not there, otherwise do nothing
    mutating func appendIfMissing(_ item: Element) {
        if !self.contains(item) {
            self.append(item)
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Iterator.Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
