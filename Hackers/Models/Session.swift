//
//  Session.swift
//  Hackers
//
//  Created by Kyle Beard on 2/3/23.
//

import Foundation

/**
 Session
 |- id: String
 |
 |- ended: <REMOVED>
 |
 |- party_code: String
 |
 |- active_game: <REMOVED>
 |
 |- format: String stroke or match
 |
 |- number_of_holes: Int
 |
 |- starting_hole: Int
 // we can compute front or back by this and # of holes
 |
 |- players: [PlayerSession]
    |- id: String
    |- name: String
    |- color: String
    |- score: HoleDict
    |- handicap: [Int: Int]
    |- team: HoleDict
 |
 |- stableford: [GameSession]
    |- id: String
    |- active: [Range] Stretch of active holes
 |
 |- vegas: [GameSession]
    |- id: String
    |- active: [Range]
 |
 |- nines: [GameSession]
    |- id: String
    |- active: [Range]
 |
 |- football: [GameSession]
    |- id: String
    |- active: [Range]
 |
 // ^^^^ games above have scoring computed by hardcoded rules
 |- monkey_in_the_middle: [GameSession]
    |- id: String
    |- active: [Range]
    |- play: HoleDict
 |
 |- bingo_bango_bongo: [GameSession]
    |- id: String
    |- active: [Range]
    |- play: [String: HoleDict]
 |
 |- cards_of_chaos: [GameSession]
    |- id: String
    |- active: [Range]
    |- difficulty: String
    |- arrangement: String
    |- teamRedraws: Int
    |- playerRedraws: [String: Int]
    |- teamRule: HoleDict
    |- playerRules: [String: HoleDict]
    // do we even want redraw limit?
 |
 |- survivor: [GameSession]
    |- id: String
    |- active: [Range]
    |- lives: [String: Int]
 |
 |- hot_potato: [GameSession]
    |- id: String
    |- active: [Range]
    |- potatoes: [Int: [String]]
    |- multiplier: String
 |
 |- hammer: [GameSession]
    |- id: String
    |- active: [Range]
    |- hammers: [Int: Int]
    // # of hammers thrown per hole
    |- first_move: HoleDict
    // name of team who made first move and then it alternates
 |
 |- banker: [GameSession]
    |- id: String
    |- active: [Range]
 |
 |- wolf_hammer: [GameSession]
    |- id: String
    |- active: [Range]
    |- junk: [JunkItem]
       |- name: String
       |- description: String
       |- point_value: Int
    |- play: [Int: WolfGameHole...]
       |- wolf: String
       |- decision: String
       |- teams: [String: [String]]
       // name map to player ids
       |- actions: [(String, String)]
       // tuple of action done and team name with index being order taken
       |- winner: String
       |- junk_dots: [String: [String]]
       // junk name and array of player ids who did it
 |
 |- side_games: [SideGame]
    |- id: String
      |- game: String
    |- holes: [Int]
    // stableford, vegas, nines, football don't have extra data
    |- data: SideGaming protocl with fields filled with all optinoal values
       |- monkey: MonkeySession?
       |- bingo: BingoSession?
       |- chaos: ChaosSession?
       |- survivor: SurvivorSession?
       |- hot_potato: HotPotatoSession?
       |- hammer: HammerSession?
       |- banker: BankerSession?
       |- wolf_hammer: WolfHammerSession?
 |- results: [GameResult]
    |- data: SideGame
 |
 |- created_at: [Time]
 |
 |- last_updated_at: [Time]
 */

struct Session: FirebaseIdentifiable {
    /// Identifier for Firebase
    var id: String
    
    /// Boolean for whether session ended
    var ended: Bool // REMOVE
    
    /// Redemption code for selected
    var partyCode: String
    
    /// ID of the player who is the current host
    var host: String // REMOVE
    
    /// Determine which game is active
    var activeGame: String // REMOVE
    
    /// Players
    var players: [PlayerSession]
    
    /// Chaos
    var chaosSession: ChaosSession
    
    /// When was the session created
    var createdAt: Time
    
    /// When was the last update
    var lastUpdatedAt: Time
    
    init(
        id: String = "",
        ended: Bool = false,
        code: String = "",
        host: String = "",
        activeGame: String = HackersGame.traditional.rawValue,
        players: [PlayerSession] = [],
        chaosSession: ChaosSession = ChaosSession(),
        createdAt: Time = Time(),
        lastUpdatedAt: Time = Time()
    ) {
        self.id = id
        self.ended = ended
        self.partyCode = code
        self.host = host
        self.activeGame = activeGame
        self.players = players
        self.chaosSession = chaosSession
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, ended, players, host
        case activeGame = "active_game"
        case partyCode = "party_code"
        case chaosSession = "chaos_session"
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
    
    private func name(for i: Int) -> String {
        return players[safe: i]?.name ?? ""
    }
    
    var playerNames: String {
        switch players.count {
        case 1:     return "\(name(for: 0))"
        case 2:     return "\(name(for: 0)) and \(name(for: 1))"
        case 3:     return "\(name(for: 0)), \(name(for: 1)), and \(name(for: 2))"
        case 4:     return "\(name(for: 0)), \(name(for: 1)), \(name(for: 2)), and \(name(for: 3))"
        default:    return ""
        }
    }
}

extension Session {
    @discardableResult
    func post() async -> Result<Session, Error> {
        print("POST - Session")
        return await self.post(to: Collections.sessions.rawValue, cache: false)
    }

    @discardableResult
    func put() async -> Result<Session, Error> {
        print("PUT - Session")
        return await self.put(to: Collections.sessions.rawValue, cache: false)
    }

    @discardableResult
    func delete() async -> Result<Bool, Error> {
        print("DELETE - Session")
        return await self.delete(from: Collections.sessions.rawValue, cache: false)
    }
}

struct PlayerSession: Hashable, Codable {
    var id: String
    var name: String
    var color: String
    var score: [Int: String]
    var handicap: [Int: Int]
    var team: String
    
    init(
        id: String = "",
        name: String = "",
        color: String = "",
        score: [Int: String] = [:],
        handicap: [Int: Int] = [:],
        team: String = ""
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.score = score
        self.handicap = handicap
        self.team = team
    }
    
    init(player: Player) {
        self.id = player.id
        self.name = player.name
        self.color = player.color.rawValue
        self.score = player.score
        self.handicap = player.handicap
        self.team = player.team
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, score, handicap, team
    }
}

enum ChaosCardsArrangement: String {
    case team, player, combo
}

enum ChaosCardsDifficulty: String {
    case easy, medium, hard
    
    var label: String {
        switch self {
        case .easy:     return "Easy"
        case .medium:   return "Medium"
        case .hard:     return "Hard"
        }
    }
    
    var randomRuleDifficulty: RuleDifficulty {
        switch self {
        case .easy:     return [.favor, .favor, .favor, .challenge][Int.random(in: 0...3)]
        case .medium:   return [.favor, .favor, .challenge, .challenge][Int.random(in: 0...3)]
        case .hard:     return [.favor, .challenge, .challenge, .challenge][Int.random(in: 0...3)]
        }
    }
}

struct ChaosSession: Hashable, Codable {
    var active: [Int]
    var arrangement: String
    var difficulty: String
    var redraws: Bool
    var teamRule: HoleRuleDictionary
    var playerRules: [String: HoleRuleDictionary]
    
    init(
        active: [Int] = [],
        arrangement: String = ChaosCardsArrangement.combo.rawValue,
        difficulty: String = ChaosCardsDifficulty.medium.rawValue,
        redraws: Bool = true,
        teamRule: HoleRuleDictionary = [:],
        playerRules: [String : HoleRuleDictionary] = [:]
    ) {
        self.active = active
        self.arrangement = arrangement
        self.difficulty = difficulty
        self.redraws = redraws
        self.teamRule = teamRule
        self.playerRules = playerRules
    }
    
    enum CodingKeys: String, CodingKey {
        case active, arrangement, difficulty, redraws
        case teamRule = "team_rule"
        case playerRules = "player_rules"
    }
}
