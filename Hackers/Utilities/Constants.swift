//
//  Constants.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import Foundation
import SwiftUI

// MARK: - Configuration

let kAppStoreURL: String = "https://apps.apple.com/us/app/hackers-golf/id6443546555"

// MARK: - User Defaulta

let kSessionID: String = "session-id"

// MARK: - View

let kPadding: CGFloat = 16.0
let kDualColumnGrid: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: kPadding), count: 2)
let kChaosCardHeight: CGFloat = 225.0

// MARK: - Models

let kHoleCount: Int = 18
let kDefaultHoles = Array(repeating: Hole(), count: 18)
let kDefaultPlayers = [Player(color: .blue), Player(color: .green), Player(color: .purple), Player(color: .red)]
