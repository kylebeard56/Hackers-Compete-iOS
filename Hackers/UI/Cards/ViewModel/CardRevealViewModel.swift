//
//  CardRevealViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/23.
//

import Foundation

enum RevealedView {
    case gameplay, caddy, drinking
}

class CardRevealViewModel: Hackable {
    //@Published var selectedView: RevealedView = .gameplay
    @Published var tab: String = "team"
    
    init() { print("init CardRevealViewModel") }
    deinit { print("deinit CardRevealViewModel") }
}
