//
//  HoleViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 7/9/23.
//

import Foundation

class HoleViewModel: Hackable {
    @Published var roundThru: Int = 0
    @Published var sideGameThru: Int = 0
    
    @Published var teams: [String] = []
    
    @Published var lastScrollOffset: CGFloat = 0.0
    
    @Published var sideGame: SideGame = .none
    @Published var sideGameSession: SideGameSession = SideGameSession()
    
    @Published var results: [SideGameSession] = []
    
    /// For each hole, this ViewModel will contain data for the specific side game that is being played.
    /// When a hole is scored, if it's the next sequential hole, add current hole to side game hole array, otherwise present
    /// tile for side game saying "you skipped holes x-x, would you like to play through?"
    
    init() {
        print("init HoleViewModel")
    }
    
    deinit {
        print("deinit HoleViewModel")
    }
}
