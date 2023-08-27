//
//  SuggestionBox.swift
//  Hackers
//
//  Created by Kyle Beard on 8/27/23.
//

import Foundation

struct SuggestionBox: FirebaseIdentifiable {
    var id: String
    var email: String
    var text: String
    
    init(
        id: String = UUID().uuidString,
        email: String = "",
        text: String
    ) {
        self.id = id
        self.email = email
        self.text = text
    }
}
