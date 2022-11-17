//
//  Constants.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import SwiftUI

// MARK: - View

let kPadding: CGFloat = 16.0
let kDualColumnGrid: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: kPadding), count: 2)

// MARK: - Models

let kDefaultHoles = Array(repeating: Hole(), count: 18)
let kDefaultPlayers = [
    Player(color: .systemBlue),
    Player(color: .systemGreen),
    Player(color: .systemPurple),
    Player(color: .systemRed),
    Player(color: .systemOrange)
]

// MARK: - Config

let kAdminDeviceIDs: [String] = [
    "FCA0CEB3-AA25-4EF4-81EB-5594EED0E071",     // Kyle's iPhone 14 Pro
    "8CBC53B3-B08E-4957-AA2D-01119152F25A"      // Kyle's Macbook Pro M1 Simulator
]
