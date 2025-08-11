//
//  LossyDecoder.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/25.
//

import Foundation
import UIKit

struct LossyDecodable<Base: Decodable>: Decodable {
    let value: Base?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try? container.decode(Base.self) // returns nil if decoding fails
    }
}

extension KeyedDecodingContainer {
    func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> [T] {
        guard let wrappedArray = try decodeIfPresent([LossyDecodable<T>].self, forKey: key) else {
            return []
        }
        return wrappedArray.compactMap { $0.value }
    }
}
