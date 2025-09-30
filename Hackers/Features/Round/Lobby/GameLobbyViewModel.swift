//
//  GameLobbyViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 9/9/25.
//

import SwiftUI

@MainActor
class GameLobbyViewModel: ObservableObject, Loggable {
    @Published var snapshot: RoundSnapshot = .init()
    
    var hostName: Name? { snapshot.participants.first(where: \.isHost)?.name }
    
    @State var showDefaultTeeSelection = false
    
    init() { }
    deinit { }
    
    func set(snapshot: RoundSnapshot) {
        addBreadcrumb(#function)
        self.snapshot = snapshot
    }
}

extension GameLobbyViewModel {

}
