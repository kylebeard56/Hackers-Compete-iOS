//
//  WolfHammerSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

enum WolfDecision: String {
    case partner = "partner"
    case lone = "lone"
    case blindLone = "blind_lone"
}

enum WolfAction: String {
    case hammer, reject, take
}

struct WolfActionData: Hashable, Codable {
    var team: String
    var action: String
}

struct JunkItem: Hashable, Codable {
    var id: String
    var name: String
    var description: String
    var value: Int
}

struct WolfHammerSession: Hashable, Codable {
    var junk: [JunkItem]
    var play: [Int: WolfHammerPlay]
}

struct WolfHammerPlay: Hashable, Codable {
    var wolf: String
    var decision: String
    var teams: [String: [String]] // [Team Name: Player IDs]
    var actions:[WolfActionData]
    var winner: String
    var junkDots: [String: [String]] // [Junk ID: Player IDs]
}
