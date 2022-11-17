//
//  Mock.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import Foundation

// MARK: - Packs

let kGameplayPack: Pack = Pack(
    id: "gameplay",
    name: "Gameplay Pack",
    icon: "\u{f451}",
    description: "Cards will guide club selection, ball advancement, and terrain.",
    style: PackStyle(primary: "pink", secondary: "yellow"))

let kDrinkingPack: Pack = Pack(
    id: "drinking",
    name: "Drinking Pack",
    icon: "\u{e0b3}",
    description: "Cards will reward or punish players with drinks based on shot or hole outcomes.",
    style: PackStyle(primary: "purple", secondary: "teal"))

// MARK: - Rules

let kBreakfastBall: Rule = Rule(
    id: "1",
    packID: "gameplay",
    name: "Breakfast Ball",
    description: "Every player on your team[-b] gets to hit (2) tee shots and pick the best one to play from penalty free.",
    icon: "\u{f7fc}",
    type: RuleType.team.rawValue,
    difficulty: RuleDifficulty.easy.rawValue)

let kTeeBoxDemotion: Rule = Rule(
    id: "2",
    packID: "gameplay",
    name: "Tee Box Demotion",
    description: "<player-name>[-b] must tee off from the next back tee.",
    icon: "\u{e551}",
    type: RuleType.player.rawValue,
    difficulty: RuleDifficulty.hard.rawValue)

let kBlindFinish: Rule = Rule(
    id: "3",
    packID: "gameplay",
    name: "Blind Finish",
    description: "<player-name>[-b] must attempt their first putt with their eyes closed.",
    icon: "\u{e481}",
    type: RuleType.player.rawValue,
    difficulty: RuleDifficulty.hard.rawValue)
