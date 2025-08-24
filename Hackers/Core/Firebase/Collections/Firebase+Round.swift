//
//  Firebase+Round.swift
//  Hackers
//
//  Created by Kyle Beard on 8/22/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

private let collection: String = Collections.rounds.rawValue

extension FirebaseService {
    func getRoundByShareCode(_ value: String) async -> Result<Round, Error> {
        addBreadcrumb("\(#function), \(value)")
        return await fetch(where: "share_code", isEqualTo: value, in: collection)
    }
}
