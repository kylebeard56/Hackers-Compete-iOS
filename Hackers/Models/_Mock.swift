//
//  Mock.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

// MARK: - Packs

let kGameplayPack: Pack = Pack(
    id: "gameplay",
    name: "Gameplay Pack",
    icon: "f451",
    description: "Cards will guide club selection, ball advancement, and terrain.",
    style: PackStyle(primary: "pink", secondary: "yellow"))

let kDrinkingPack: Pack = Pack(
    id: "drinking",
    name: "Drinking Pack",
    icon: "e0b3",
    description: "Cards will reward or punish players with drinks based on shot or hole outcomes.",
    style: PackStyle(primary: "purple", secondary: "teal"))

// MARK: - Rules

let kMissingGameplayRule: Rule = Rule(
    id: "69420",
    packID: "gameplay",
    name: "Missing Rule",
    description: "[-b]We weren't able to come up with a rule, and that's on us! Please reload.",
    icon: "f7fc",
    type: RuleType.player.rawValue,
    difficulty: RuleDifficulty.favor.rawValue)

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

// MARK: - Players

let kPlayerKyle = Player(id: "beard", name: "Kyle", color: Color.systemGray, difficulty: .medium, redrawCount: 3)

