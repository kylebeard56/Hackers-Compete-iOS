//
//  NinesReultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/23.
//

import SwiftUI

struct NinesReultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    @State private var data: [NinesData] = []
    @State private var winner: String = ""
    @State private var expand: Bool = false
    
    var body: some View {
        SideGameResultsView(session: session, winnerLabel: winner, content: { content } )
            .onAppear() { compute() }
            .onReceive(roundSession.$players, perform: { _ in compute() })
    }
    
    // MARK: - Views
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 10) {
            ForEach(data, id: \.self) { d in
                let name = roundSession.players.first(where: { $0.id == d.player })?.name ?? ""
                HStack(spacing: 0) {
                    Text(name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text("\(d.value)")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }
    
    // MARK: - Computation
    
    private func compute() {
        data = ScoringService.Nines.computeResults(for: roundSession.players, over: session.holes)
    }
}

struct NinesReultsView_Previews: PreviewProvider {
    static var previews: some View {
        NinesReultsView(session: SideGameSession())
    }
}
