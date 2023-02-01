//
//  GameDifficultyTest.swift
//  HackersTests
//
//  Created by Kyle Beard on 1/29/23.
//

@testable import Hackers
import XCTest

final class GameDifficultyTest: XCTestCase {
    override func setUpWithError() throws { }
    override func tearDownWithError() throws { }
    
    func testGameDifficultyProbability() throws {
        var easyMode: [RuleDifficulty] = []
        var mediumMode: [RuleDifficulty] = []
        var hardMode: [RuleDifficulty] = []
        for _ in 0...999 {
            easyMode.append(GameDifficulty.easy.randomRuleDifficulty)
            mediumMode.append(GameDifficulty.medium.randomRuleDifficulty)
            hardMode.append(GameDifficulty.hard.randomRuleDifficulty)
        }
        let easyFavors: Int = easyMode.filter({ $0 == .favor }).count
        let mediumFavors: Int = easyMode.filter({ $0 == .favor }).count
        let hardFavors: Int = easyMode.filter({ $0 == .favor }).count
        
        // Easy Mode is 75% chance of favor with +/- %5
        XCTAssertGreaterThanOrEqual(easyFavors, 700)
        XCTAssertLessThanOrEqual(easyFavors, 800)
        
        // Medium Mode is 50% chance of favor with +/- %5
        XCTAssertGreaterThanOrEqual(mediumFavors, 450)
        XCTAssertLessThanOrEqual(mediumFavors, 550)
        
        // Hard Mode is 25% chance of favor with +/- %5
        XCTAssertGreaterThanOrEqual(hardFavors, 200)
        XCTAssertLessThanOrEqual(hardFavors, 300)
    }
}
