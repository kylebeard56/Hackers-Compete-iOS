//
//  SideGame.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

enum SideGameComplexity {
    case low, medium, high
}

enum SideGameStructure: String {
    case individual = "Individual"
    case team = "Team"
    case both = "Both"
}

enum SideGamePace: String {
    case slower = "Slower"
    case normal = "Normal"
    case faster = "Faster"
}

enum SideGame: String, CaseIterable {
    case banker = "banker"
    case bingoBangoBongo = "bingo_bango_bongo"
    case cardsOfChaos = "cards_of_chaos"
    case football = "football"
    case hammer = "hammer"
    case hotPotato = "hot_potato"
    case monkeyInTheMiddle = "monkey_in_the_middle"
    case nines = "nines"
    case stableford = "stableford"
    case survivor = "survivor"
    case vegas = "vegas"
    case wolfHammer = "wolf_hammer"
    
    var name: String {
        switch self {
        case .banker:               return "Banker"
        case .bingoBangoBongo:      return "Bingo Bango Bongo"
        case .cardsOfChaos:         return "Cards of Chaos"
        case .football:             return "Football"
        case .hammer:               return "Hammer"
        case .hotPotato:            return "Hot Potato"
        case .monkeyInTheMiddle:    return "Monkey in the Middle"
        case .nines:                return "Nines"
        case .stableford:           return "Stableford"
        case .survivor:             return "Survivor"
        case .vegas:                return "Vegas"
        case .wolfHammer:           return "Wolf Hammer"
        }
    }
    
    var icon: String {
        switch self {
        case .banker:               return "f19c"
        case .bingoBangoBongo:      return "e3ac"
        case .cardsOfChaos:         return "f71d"
        case .football:             return "f44e"
        case .hammer:               return "f6e3"
        case .hotPotato:            return "e440"
        case .monkeyInTheMiddle:    return "f6fb"
        case .nines:                return "e0f6"
        case .stableford:           return "f6f0"
        case .survivor:             return "f21e"
        case .vegas:                return "e3ce"
        case .wolfHammer:           return "f702"
        }
    }
    
    var description: String {
        switch self {
        case .banker:               return "One player battles and wagers against the others in simultaneous 1v1 matches."
        case .bingoBangoBongo:      return "Battle for points on each hole in competition around the green."
        case .cardsOfChaos:         return "Players draw amusing card that contain rules for how they can play a hole."
        case .football:             return "Score points from hole performances that mimics our pigskin favorite."
        case .hammer:               return "2v2 play where teams can strategically double the stakes back and forth."
        case .hotPotato:            return "2v2 play with multiplied scoring if you're holding the hot potato."
        case .monkeyInTheMiddle:    return "A fun 1v2 game for parties of 3 that introduces unique strategy off the tee."
        case .nines:                return "A competitive game for parties of 3 that allocates nine points per hole."
        case .stableford:           return "Alternative scoring that doesn't punish player for bad holes."
        case .survivor:             return "Players fight to avoid losing lives from scoring outcomes."
        case .vegas:                return "2v2 play that combines player scores on each team lowest to highest."
        case .wolfHammer:           return "An intense game of best ball with strategic team and scoring opportunities."
        }
    }
    
    var players: [Int] {
        switch self {
        case .banker:               return [3, 4]
        case .bingoBangoBongo:      return [2, 3, 4]
        case .cardsOfChaos:         return [1, 2, 3, 4]
        case .football:             return [1, 2, 3, 4]
        case .hammer:               return [2, 4]
        case .hotPotato:            return [2, 3, 4]
        case .monkeyInTheMiddle:    return [3]
        case .nines:                return [3]
        case .stableford:           return [1, 2, 3, 4]
        case .survivor:             return [2, 3, 4]
        case .vegas:                return [4]
        case .wolfHammer:           return [4]
        }
    }
    
    var structure: SideGameStructure {
        switch self {
        case .banker:               return .individual
        case .bingoBangoBongo:      return .both
        case .cardsOfChaos:         return .both
        case .football:             return .both
        case .hammer:               return .team
        case .hotPotato:            return .both
        case .monkeyInTheMiddle:    return .individual
        case .nines:                return .individual
        case .stableford:           return .both
        case .survivor:             return .both
        case .vegas:                return .team
        case .wolfHammer:           return .individual
        }
    }
    
    /// If true, the leaderboard individual or teams must be set or match the side game format.
    var forceStructure: Bool {
        switch self {
        case .banker:               return false
        case .bingoBangoBongo:      return false
        case .cardsOfChaos:         return false
        case .football:             return false
        case .hammer:               return true
        case .hotPotato:            return false
        case .monkeyInTheMiddle:    return false
        case .nines:                return false
        case .stableford:           return false
        case .survivor:             return false
        case .vegas:                return true
        case .wolfHammer:           return false
        }
    }
    
    var complexity: SideGameComplexity {
        switch self {
        case .banker:               return .high
        case .bingoBangoBongo:      return .low
        case .cardsOfChaos:         return .medium
        case .football:             return .low
        case .hammer:               return .medium
        case .hotPotato:            return .low
        case .monkeyInTheMiddle:    return .low
        case .nines:                return .medium
        case .stableford:           return .low
        case .survivor:             return .medium
        case .vegas:                return .low
        case .wolfHammer:           return .high
        }
    }
    
    var trueScoring: Bool {
        return self != .cardsOfChaos
    }
}
