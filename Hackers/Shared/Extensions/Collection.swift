//
//  Collection.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation

extension Collection {
    func partition(into partitions: Int) -> [[Element]] {
        enumerated().reduce(into: [[Element]](repeating: [], count: partitions)) {
            $0[$1.offset % partitions].append($1.element)
        }
    }
    
   var isPopulated: Bool {
       return !self.isEmpty
   }
    
    subscript(safe index: Index) -> Iterator.Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

extension Optional where Wrapped: Collection {
   var isPopulated: Bool {
       return self?.isEmpty == false
   }
}
