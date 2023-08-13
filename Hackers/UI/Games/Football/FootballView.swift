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
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct FootballView_Previews: PreviewProvider {
    static var previews: some View {
        FootballView()
    }
}
