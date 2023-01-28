//
//  Collection.swift
//  Hackers
//
//  Created by Kyle Beard on 12/4/22.
//

import Foundation

extension Collection {
    func partition(into partitions: Int) -> [[Element]] {
        enumerated().reduce(into: [[Element]](repeating: [], count: partitions)) {
            $0[$1.offset % partitions].append($1.element)
        }
    }
}
