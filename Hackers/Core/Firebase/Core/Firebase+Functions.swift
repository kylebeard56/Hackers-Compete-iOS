//
//  Firebase+Functions.swift
//  Hackers
//
//  Created by Kyle Beard on 10/6/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import FirebaseFunctions
import Foundation
import SwiftUI

enum FirestoreFunctionName: String {
    case recursiveDelete = "recursiveDelete"
    
    var name: String { self.rawValue }
    func function() -> HTTPSCallable { Functions.functions().httpsCallable(self.name) }
}

extension FirebaseService {
    func delete(round: Round) async {
        addBreadcrumb("\(#function), id: \(round.id)")
        
        do {
            let path = "\(Collections.rounds)/\(round.id)"
            let result = try await FirestoreFunctionName.recursiveDelete.function().call(["path": path])
        } catch {
            addBreadcrumb(.error, .firebase, "Cloud Function failed to delete round, \(round.id)", error)
        }
    }
}
