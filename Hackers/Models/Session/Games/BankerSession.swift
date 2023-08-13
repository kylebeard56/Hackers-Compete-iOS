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
    
    init(
        banker: [Int : String] = [:],
        wagers: [Int : [String : Int]] = [:],
        presses: [Int : [String : Bool]] = [:],
        parThree: [Int : Bool] = [:]
    ) {
        self.banker = banker
        self.wagers = wagers
        self.presses = presses
        self.parThree = parThree
    }
}
