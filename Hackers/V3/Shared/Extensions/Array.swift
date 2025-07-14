//
//  Array.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation

extension Array where Element: Equatable {
    /// Insert an element into the array if it doesn't exist, update the element if it does.
    mutating func upsert(_ newElement: Element) {
        if let index = firstIndex(of: newElement) {
            self[index] = newElement
        } else {
            append(newElement)
        }
    }
    
    /// Insert an element into the array if it doesn't exist, remove the element if it does.
    mutating func toggle(_ element: Element) {
        if self.contains(element) {
            self.removeAll(where: { $0 == element })
        } else {
            self.append(element)
        }
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return self.filter { seen.insert($0).inserted }
    }

    mutating func removeDuplicates() {
        self = self.removingDuplicates()
    }
}
