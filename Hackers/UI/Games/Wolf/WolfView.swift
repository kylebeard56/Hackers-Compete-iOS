//
//  WolfView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/23/23.
//

import SwiftUI

struct WolfView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var data: [GameScoreData] = []
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct WolfView_Previews: PreviewProvider {
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGame = .wolfHammer
        vm.sideGameSession.holes = [1, 2, 3, 4]
        vm.sideGameSession.wolfHammer = nil
        return vm
    }
    
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = previewPlayers
        return rs
    }
    
    static var previewPlayers: [Player] {
        var k = kPlayerKyle
        var s = kPlayerSarah
        var m = kPlayerMurphy
        var p = kPlayerPablo
        
        k.score = [1: "par", 2: "par", 3: "par", 4: "par"]
        s.score = [1: "par", 2: "par", 3: "birdie", 4: "par"]
        m.score = [1: "par", 2: "birdie", 3: "par", 4: "par"]
        p.score = [1: "birdie", 2: "par", 3: "par", 4: "birdie"]
        
        return [k, s, m, p]
    }
    
    static var previews: some View {
        ScrollView {
            BankerView(viewModel: viewModel, hole: 1)
                .alignTop()
        }
        .environmentObject(roundSession)
        .padding(.horizontal, 20)
        .holisticPreview()
    }
}
