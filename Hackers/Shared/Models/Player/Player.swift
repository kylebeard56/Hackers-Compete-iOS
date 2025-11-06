//
//  Player.swift
//  Hackers
//
//  Created by Kyle Beard on 8/19/25.
//

import Foundation

protocol Playable {
    /// DB internal ID
    var id: String { get set }
    
    /// ID of the `HackersUser` (nil if offline player)
    var userID: String?  { get set }
    
    /// ID of the `PlayerProfile` (nil if offline)
    var playerID: String? { get set }
    
    /// Friendly display name
    var name: Name { get set }
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
