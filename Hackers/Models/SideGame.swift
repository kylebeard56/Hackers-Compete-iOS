//
//  SideGame.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation
import UIKit

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
    case bestBall = "best_ball"
    case bingo = "bingo_bango_bongo"
    case cardsOfChaos = "cards_of_chaos"
    case checkpoint = "checkpoint"
    case fibonacci = "fibonacci"
    case football = "football"
    case golfBingo = "golf_bingo"
    case hammer = "hammer"
    case hotPotato = "hot_potato"
    case jackpot = "jackpot"
    case medalPlay = "medal_play"
    case monkeyInTheMiddle = "monkey_in_the_middle"
    case nines = "nines"
    case stableford = "stableford"
    case survivor = "survivor"
    case twentyOne = "twenty_one"
    case vegas = "vegas"
    case wolfHammer = "wolf_hammer"
    case none = "none"
    
    var priority: Bool {
        switch self {
        case .cardsOfChaos:         return true
        default:                    return false
        }
    }
    
    var tag: String? {
        switch self {
        case .cardsOfChaos:         return "FEATURED"
        default:                    return nil
        }
    }
        
    var image: UIImage? {
        switch self {
        case .cardsOfChaos:         return Asset.Images.cardsOfChaos.image
        default:                    return nil
        }
    }
    
    var underConstruction: Bool {
        switch self {
        case .banker:               return false
        case .bestBall:             return false
        case .bingo:                return false
        case .cardsOfChaos:         return false
//        case .checkpoint:           return false
        case .fibonacci:            return false
        case .football:             return false
//        case .golfBingo:            return false
//        case .hammer:               return false
//        case .hotPotato:            return false
//        case .jackpot:              return false
        case .medalPlay:            return false
        case .monkeyInTheMiddle:    return false
        case .nines:                return false
        case .stableford:           return false
//        case .survivor:             return false
//        case .twentyOne:            return false
        case .vegas:                return false
//        case .wolfHammer:           return false
        default:                    return true
        }
    }
    
    var computedFromScoring: Bool {
        switch self {
        case .banker:               return true
        case .bestBall:             return true
        case .bingo:                return false
        case .cardsOfChaos:         return false
//        case .checkpoint:           return false
        case .fibonacci:            return true
        case .football:             return false // banners already integrated into gameplay
//        case .golfBingo:            return false
//        case .hammer:               return false
//        case .hotPotato:            return false
//        case .jackpot:              return false
        case .medalPlay:            return true
        case .monkeyInTheMiddle:    return true
        case .nines:                return true
        case .stableford:           return true
//        case .survivor:             return false
//        case .twentyOne:            return false
        case .vegas:                return true
//        case .wolfHammer:           return false
        default:                    return true
        }
    }
    
    var name: String {
        switch self {
        case .banker:               return "Banker"
        case .bestBall:             return "Best Ball (Skins)"
        case .bingo:                return "Bingo Bango Bongo"
        case .cardsOfChaos:         return "Cards of Chaos"
        case .checkpoint:           return "Checkpoint"
        case .fibonacci:            return "Fibonacci"
        case .football:             return "Football"
        case .hammer:               return "Hammer"
        case .hotPotato:            return "Hot Potato"
        case .golfBingo:            return "Golf Bingo"
        case .jackpot:              return "Jackpot"
        case .medalPlay:            return "Medal Play"
        case .monkeyInTheMiddle:    return "Monkey in the Middle"
        case .nines:                return "Nines"
        case .stableford:           return "Stableford"
        case .survivor:             return "Survivor"
        case .twentyOne:            return "21"
        case .vegas:                return "Vegas"
        case .wolfHammer:           return "Wolf Hammer"
        default:                    return "not set"
        }
    }
    
    var icon: String {
        switch self {
        case .banker:               return "f19c"
        case .bestBall:             return "f450"
        case .bingo:                return "e3ac"
        case .cardsOfChaos:         return "f71d"
        case .checkpoint:           return "f11e"
        case .fibonacci:            return "e02f"
        case .football:             return "f44e"
        case .golfBingo:            return "f867"
        case .hammer:               return "f6e3"
        case .hotPotato:            return "e440"
        case .jackpot:              return "f73e"
        case .medalPlay:            return "f5a2"
        case .monkeyInTheMiddle:    return "f6fb"
        case .nines:                return "e0f6"
        case .stableford:           return "f6f0"
        case .survivor:             return "f21e"
        case .twentyOne:            return "f434"
        case .vegas:                return "e3ce"
        case .wolfHammer:           return "f1b0"
        default:                    return ""
        }
    }
    
    var description: String {
        switch self {
        case .banker:               return "One player battles and wagers against the others in simultaneous 1v1 matches (includes two ball)."
        case .bestBall:             return "Match play style for individuals or teams to battle each other (includes skins)."
        case .bingo:                return "Battle for points on each hole in competition around the green."
        case .cardsOfChaos:         return "Players draw amusing card that contain rules for how they can play a hole."
        case .checkpoint:           return "Be the first player to complete golf tasks in sequential order to win."
        case .fibonacci:            return "Alternative scoring that gives points following the Fibonacci sequence."
        case .football:             return "Score points by winning holes with a twist that mimics our pigskin favorite."
        case .golfBingo:            return "Players battle to fill their cards from other's gameplay during the round."
        case .hammer:               return "2v2 play where teams can strategically double the stakes back and forth."
        case .hotPotato:            return "Scoring penalties await the last player holding this glorious spud when the hole ends."
        case .jackpot:              return "Missed putts add points to a pot that rewards whoever makes the next one putt."
        case .medalPlay:            return "Stroke play style for individual or team mini leaderboards."
        case .monkeyInTheMiddle:    return "A fun 1v2 game for parties of 3 that introduces unique strategy off the tee."
        case .nines:                return "A competitive game for parties of 3 that allocates nine points per hole."
        case .stableford:           return "Alternative scoring that doesn't punish player for bad holes."
        case .survivor:             return "Players fight to avoid losing lives from scoring outcomes."
        case .twentyOne:            return "Be the first to score 21 points without getting tipped by other players."
        case .vegas:                return "2v2 play that combines player scores on each team lowest to highest."
        case .wolfHammer:           return "An intense game of best ball with strategic team and scoring opportunities."
        default:                    return ""
        }
    }
    
    var players: [Int] {
        switch self {
        case .banker:               return [3, 4]
        case .bestBall:             return [2, 3, 4]
        case .bingo:                return [2, 3, 4]
        case .cardsOfChaos:         return [1, 2, 3, 4]
        case .checkpoint:           return [1, 2, 3, 4]
        case .fibonacci:            return [1, 2, 3, 4]
        case .football:             return [4]
        case .golfBingo:            return [2, 3, 4]
        case .hammer:               return [2, 4]
        case .hotPotato:            return [2, 3, 4]
        case .jackpot:              return [2, 3, 4]
        case .medalPlay:            return [1, 2, 3, 4]
        case .monkeyInTheMiddle:    return [3]
        case .nines:                return [3]
        case .stableford:           return [1, 2, 3, 4]
        case .survivor:             return [2, 3, 4]
        case .twentyOne:            return [2, 3, 4]
        case .vegas:                return [4]
        case .wolfHammer:           return [4]
        default:                    return []
        }
    }
    
    var playerLabel: String {
        switch self {
        case .banker:               return "3 or 4"
        case .bestBall:             return "2 to 4"
        case .bingo:                return "2 to 4"
        case .cardsOfChaos:         return "1 to 4"
        case .checkpoint:           return "1 to 4"
        case .fibonacci:            return "1 to 4"
        case .football:             return "4"
        case .golfBingo:            return "2 to 4"
        case .hammer:               return "2 or 4"
        case .hotPotato:            return "2 to 4"
        case .jackpot:              return "2 to 4"
        case .medalPlay:            return "1 to 4"
        case .monkeyInTheMiddle:    return "3"
        case .nines:                return "3"
        case .stableford:           return "1 to 4"
        case .survivor:             return "2 to 4"
        case .twentyOne:            return "2 to 4"
        case .vegas:                return "4"
        case .wolfHammer:           return "4"
        default:                    return ""
        }
    }
    
    var structure: SideGameStructure {
        switch self {
        case .banker:               return .individual
        case .bestBall:             return .both
        case .bingo:                return .both
        case .cardsOfChaos:         return .both
        case .checkpoint:           return .both
        case .fibonacci:            return .both
        case .football:             return .team
        case .golfBingo:            return .both
        case .hammer:               return .team
        case .hotPotato:            return .both
        case .jackpot:              return .both
        case .medalPlay:            return .both
        case .monkeyInTheMiddle:    return .individual
        case .nines:                return .individual
        case .stableford:           return .both
        case .survivor:             return .both
        case .twentyOne:            return .individual
        case .vegas:                return .team
        case .wolfHammer:           return .individual
        default:                    return .both
        }
    }
    
    /// If true, the leaderboard individual or teams must be set or match the side game format.
//    var forceStructure: Bool {
//        switch self {
//        case .banker:               return false
//        case .bestBall:             return true
//        case .bingo:      return false
//        case .bingo:                return false
//        case .cardsOfChaos:         return false
//        case .checkpoint:           return false
//        case .fibonacci:            return false
//        case .football:             return true
//        case .hammer:               return true
//        case .hotPotato:            return false
//        case .jackpot:              return false
//        case .medalPlay:            return false
//        case .monkeyInTheMiddle:    return false // Doesn't matter, they cannot make teams w/ 3 people.
//        case .nines:                return false // Doesn't matter, they cannot make teams w/ 3 people.
//        case .stableford:           return false
//        case .survivor:             return false
//        case .twentyOne:            return false
//        case .vegas:                return true
//        case .wolfHammer:           return false
//        default:                    return false
//        }
//    }
    
    var complexity: SideGameComplexity {
        switch self {
        case .banker:               return .high
        case .bestBall:             return .low
        case .bingo:                return .low
        case .cardsOfChaos:         return .medium
        case .checkpoint:           return .medium
        case .fibonacci:            return .low
        case .football:             return .medium
        case .golfBingo:            return .low
        case .jackpot:              return .low
        case .hammer:               return .medium
        case .hotPotato:            return .low
        case .medalPlay:            return .low
        case .monkeyInTheMiddle:    return .low
        case .nines:                return .medium
        case .stableford:           return .low
        case .survivor:             return .medium
        case .twentyOne:            return .medium
        case .vegas:                return .low
        case .wolfHammer:           return .high
        default:                    return .low
        }
    }
    
    var pace: SideGamePace {
        switch self {
        case .banker:               return .normal
        case .bestBall:             return .faster
        case .bingo:                return .normal
        case .cardsOfChaos:         return .slower
        case .checkpoint:           return .normal
        case .fibonacci:            return .normal
        case .football:             return .faster
        case .golfBingo:            return .normal
        case .hammer:               return .normal
        case .hotPotato:            return .normal
        case .jackpot:              return .normal
        case .medalPlay:            return .normal
        case .monkeyInTheMiddle:    return .normal
        case .nines:                return .normal
        case .stableford:           return .normal
        case .survivor:             return .normal
        case .twentyOne:            return .normal
        case .vegas:                return .normal
        case .wolfHammer:           return .normal
        default:                    return .normal
        }
    }
    
    // MARK: - Tagging
    
    static var allGames: [SideGame] {
        SideGame.allCases.filter({ $0 != .none })
    }
    
    /// Games that are played individually
    static var individualGames: [SideGame] {
        SideGame.allCases.filter({ $0.structure != .team })
    }
    
    /// Games that are played as a team
    static var teamGames: [SideGame] {
        SideGame.allCases.filter({ $0.structure != .individual })
    }
    
    /// Games that are easy going and simple concepts
    static var relaxedGames: [SideGame] {
        [.bestBall, .bingo, .cardsOfChaos, .checkpoint, .fibonacci, .golfBingo, .jackpot, .stableford]
    }
    
    /// Games that are easy to understand and relaxed
    static var bettingGames: [SideGame] {
        [.banker, .bestBall, .football, .hammer, .nines, .medalPlay, .vegas, .wolfHammer]
    }
    
    /// Games that are easy to understand and relaxed
    static var competitiveGames: [SideGame] {
        [.banker, .bestBall, .football, .hammer, .hotPotato, .medalPlay, .monkeyInTheMiddle, .nines, .survivor, .twentyOne, .vegas, .wolfHammer]
    }
    
    /// Games that are original content
    static var madeByHackers: [SideGame] {
        [.cardsOfChaos, .checkpoint,.fibonacci, .football, .golfBingo, .hotPotato, .jackpot, .monkeyInTheMiddle, .survivor, .twentyOne]
    }
    
    /// Games that don't need your hole-by-hole scoring to play
    static var amateurGames: [SideGame] {
        [.bingo, .cardsOfChaos, .checkpoint, .golfBingo, .jackpot]
    }
}
