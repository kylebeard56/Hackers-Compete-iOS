//
//  SideGame.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/23.
//

import Foundation

struct SideGameSession: Hashable, Codable, Equatable {
    var id: String
    var game: String // Name of the side game
    var holes: [Int] // Range of active holes
    var stroke: StrokeSession?
    var match: MatchSession?
    var monkey: MonkeySession?
    var bingo: BingoSession?
    var chaos: ChaosSession?
    var survivor: SurvivorSession?
    var hotPotato: HotPotatoSession?
    var hammer: HammerSession?
    var banker: BankerSession?
    var wolfHammer: WolfHammerSession?
    var football: FootballSession?
    
    init(
        id: String = "",
        game: String = "",
        holes: [Int] = [],
        stroke: StrokeSession? = nil,
        match: MatchSession? = nil,
        monkey: MonkeySession? = nil,
        bingo: BingoSession? = nil,
        chaos: ChaosSession? = nil,
        survivor: SurvivorSession? = nil,
        hotPotato: HotPotatoSession? = nil,
        hammer: HammerSession? = nil,
        banker: BankerSession? = nil,
        wolfHammer: WolfHammerSession? = nil,
        football: FootballSession? = nil
    ) {
        self.id = id
        self.game = game
        self.holes = holes
        self.stroke = stroke
        self.match = match
        self.monkey = monkey
        self.bingo = bingo
        self.chaos = chaos
        self.survivor = survivor
        self.hotPotato = hotPotato
        self.hammer = hammer
        self.banker = banker
        self.wolfHammer = wolfHammer
        self.football = football
    }
    
    enum CodingKeys: String, CodingKey {
        case id, game, holes, stroke, match, monkey, bingo, chaos, survivor, hammer, banker, football
        case hotPotato = "hot_potato"
        case wolfHammer = "wolf_hammer"
    }
}
