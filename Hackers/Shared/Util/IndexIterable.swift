//
//  IndexIterable.swift
//  Hackers
//
//  Created by Kyle Beard on 12/16/25.
//

import SwiftUI

protocol IndexIterable {
    var index: Int { get set }
}

extension Collection where Element: IndexIterable {
    var nextIndex: Int {
        (self.compactMap(\.index).max() ?? -1) + 1
    }
}
