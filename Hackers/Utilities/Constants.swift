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

let kHoleCount: Int = 18
let kDefaultHoles = Array(repeating: Hole(), count: 18)
let kDefaultPlayers = [
    Player(color: .systemBlue),
    Player(color: .systemGreen),
    Player(color: .systemPurple),
    Player(color: .systemRed),
    Player(color: .systemOrange)
]
