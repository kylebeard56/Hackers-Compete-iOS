//
//  Mock.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

// MARK: - Players

let kPlayerKyle = Player(id: "kyle", name: "Kyle", color: .blue, team: [1: "Team one"])
let kPlayerSarah = Player(id: "sarah", name: "Sarah", color: .green, team: [1: "Team one"])
let kPlayerMurphy = Player(id: "murphy", name: "Murphy", color: .purple, team: [1: "Team two"])
let kPlayerPablo = Player(id: "pablo", name: "Pablo", color: .pink, team: [1: "Team two"])

// MARK: - Session

let kSession: Session = Session(
    id: "",
    partyCode: "Caddyshack69",
    players: [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo].compactMap({ PlayerSession(player: $0) }),
    sideGames: [],
    createdAt: Time(),
    lastUpdatedAt: Time())

// MARK: - Rules

let kBreakfastBall: Rule = Rule(
    id: "1",
    packID: "gameplay",
    name: "Breakfast Ball",
    description: "Every player on your team[-b] gets to hit (2) tee shots and pick the best one to play from penalty free. This is extra text for a fourth line.",
    icon: "f7fc",
    type: RuleType.team.rawValue,
    difficulty: RuleDifficulty.favor.rawValue)

let kTeeBoxDemotion: Rule = Rule(
    id: "2",
    packID: "gameplay",
    name: "Tee Box Demotion",
    description: "<player-name>[-b] must tee off from back tee.",
    icon: "e551",
    type: RuleType.player.rawValue,
    difficulty: RuleDifficulty.challenge.rawValue)

let kBlindFinish: Rule = Rule(
    id: "3",
    packID: "gameplay",
    name: "Blind Finish",
    description: "<player-name>[-b] must attempt their first putt with their eyes closed.",
    icon: "e481",
    type: RuleType.player.rawValue,
    difficulty: RuleDifficulty.challenge.rawValue)
