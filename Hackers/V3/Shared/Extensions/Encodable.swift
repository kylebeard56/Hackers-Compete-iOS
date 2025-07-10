//
//  Encodable.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation

extension Encodable {
    /// Converts an Encodable struct to a [String: Any] dictionary
    func toDictionary() throws -> [String: Any] {
        let jsonData = try JSONEncoder().encode(self)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: .fragmentsAllowed)
        guard let dictionary = jsonObject as? [String: Any] else { throw HackersError.failedToEncodeDocument }
        return dictionary
    }
}
