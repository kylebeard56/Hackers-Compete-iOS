//
//  AppSession.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Combine
import FirebaseAuth
import SwiftUI

@MainActor
class AppSession: Hackable {
    @Published var players: [Player] = []
    
    init() {
        print("init AppSession")
    }
    
    deinit { print("deinit AppSession") }
}
