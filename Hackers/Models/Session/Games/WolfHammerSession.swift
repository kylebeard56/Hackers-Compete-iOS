//
//  WolfHammerSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

/// Phase 1 (on each hole):
/// =====
/// 1. Who is the wolf?
/// 2. Is the wolf playing with a partner (if so, who?) or are they going lone (if so, blind?)
/// 3. Events - who hammered? what was the response (take or reject)?
///     - Note: Boomerang can be a shortcut to complete one event and the hammer the other group?
/// 4. Who won the hole?
///
/// Phase 2
/// =====
/// 1. What junk points were scored for who?
/// 2. Where do we store common Junk items (and custom)?
///     - We could have a marketplace of Junk items people create and posted for others to use.

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
