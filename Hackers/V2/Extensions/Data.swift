//
//  Data.swift
//  Hackers
//
//  Created by Kyle Beard on 8/17/23.
//

import Foundation

extension Data {
    var checksum: Int {
        return self.map { Int($0) }.reduce(0, +) & 0xff
    }
}
