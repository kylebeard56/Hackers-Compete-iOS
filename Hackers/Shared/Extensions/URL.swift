//
//  URL.swift
//  Hackers
//
//  Created by Kyle Beard on 1/8/26.
//

import Foundation

extension URL {
    var extractRoundID: String? {
        if self.path != "/join" { return nil }
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "round_id" })?
            .value
    }
}
