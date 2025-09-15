//
//  GameLobbyViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import SwiftUI

@MainActor
class GameLobbyViewModel: ObservableObject, Loggable {
    @Published var roundID = ""
    
    init() { }
    deinit { }
}

extension GameLobbyViewModel {
    func getSnapshot() async {
        addBreadcrumb(#function)
    }
}
