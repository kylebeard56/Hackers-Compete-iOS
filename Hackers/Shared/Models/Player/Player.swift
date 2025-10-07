//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 8/19/25.
//

import Foundation

protocol Playable {
    var id: String { get set }
    var userID: String?  { get set }
}

//struct Player: FirebaseIdentifiable, Playable {
//    var id: String
//    var userID: String?
//    
//    var rounds: [String]
//    
//    var createdAt: Time
//    var lastUpdatedAt: Time
//    var collection: String { Collections.players.name }
//}
