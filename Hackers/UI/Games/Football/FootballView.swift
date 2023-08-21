//
//  FootballView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

/// Requires teams of 4 set 2v2
/// On first tee, we say possession is furthest off tee, then for future holes it's whoever had possession unless scoring.
///
/// While playing,
///     Lost ball or bunker hit is a change of possession (sequentially).
///     Once everyone finishes hole, scoring is based based on final possession.
///
/// When done,
///    if offensive team has best ball, they have option to take FG or go for TD (win hole again).
///    if defense has best ball (or tie), they get turnover on downs and possession next hole.
///    if both defensive players beat offense, they get safety and possession next hole.


struct FootballView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    @State private var possession: String = ""
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct FootballView_Previews: PreviewProvider {
    static var viewModel: HoleViewModel {
        let vm = HoleViewModel()
        vm.sideGameSession.holes = [1, 2, 3, 4]
        //vm.sideGameSession.football =
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
            FootballView(viewModel: viewModel, hole: 1)
                .alignTop()
        }
        .environmentObject(roundSession)
        .padding(.horizontal, 20)
        .holisticPreview()
    }
}
