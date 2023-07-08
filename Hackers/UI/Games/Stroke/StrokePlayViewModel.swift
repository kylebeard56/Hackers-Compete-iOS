//
//  StrokePlayViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

enum StrokeScoringFormat {
    case medal, stableford, football
}

@MainActor
class StrokePlayViewModel: Hackable {
    // TODO: Read below
    /// This should essentially update with static, read-only data since it computes scoring from RoundViewModel.
    
    @Published var format: StrokeScoringFormat = .medal
    
    init() { print("init StrokePlayViewModel") }
    deinit { print("deinit StrokePlayViewModel") }
}
