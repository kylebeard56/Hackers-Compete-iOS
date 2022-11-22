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

// MARK: - Config

let kAdminDeviceIDs: [String] = [
    "38D713DE-4689-4AFE-928C-5627164FAE51",     // Kyle's iPhone 14 Pro
    "DD22471C-2C22-432E-B34A-84A5D1A1E254"      // Kyle's Macbook Pro M1 Simulator
]
