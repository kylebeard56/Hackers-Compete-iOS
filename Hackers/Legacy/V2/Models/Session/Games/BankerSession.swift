//
//  BankerSession.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation

struct BankerSession: Hashable, Codable {
    var banker: [Int: String]
    var wagers: [Int: [String: Int]]
    var presses: [Int: [String: Bool]]
    var parThree: [Int: Bool]
    var maxWager: Int?
    var normalMultiplier: Int?
    var parThreeMultiplier: Int?
    
    init(
        banker: [Int : String] = [:],
        wagers: [Int : [String : Int]] = [:],
        presses: [Int : [String : Bool]] = [:],
        parThree: [Int : Bool] = [:],
        maxWager: Int? = 100,
        normalMultiplier: Int? = 2,
        parThreeMultiplier: Int? = 3
    ) {
        self.banker = banker
        self.wagers = wagers
        self.presses = presses
        self.parThree = parThree
        self.maxWager = maxWager
        self.normalMultiplier = normalMultiplier
        self.parThreeMultiplier = parThreeMultiplier
    }
}
