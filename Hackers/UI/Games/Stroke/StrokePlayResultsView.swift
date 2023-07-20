//
//  StrokePlayResultsView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/16/23.
//

import SwiftUI

private struct StrokeData: Hashable, Identifiable {
    var id: UUID = UUID()
    var player: Player
    var value: Int
}

struct StrokePlayResultsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    var session: SideGameSession
    
    private var format: StrokeScoringFormat {
        switch session.game {
        case SideGame.stableford.rawValue:
            return .stableford
        case SideGame.fibonacci.rawValue:
            return .fibonacci
        default:
            return .medal
        }
    }
    
    @State private var data: [StrokeData] = []
    @State private var winner: String = ""
    @State private var expand: Bool = false
    
    @State private var isTwoBall: Bool = false
    @State private var twoBallScore: String = ""
    
    var body: some View {
        SideGameResultsView(
            session: session,
            winnerLabel: winner,
            content: { content }
        )
        .onAppear() { compute() }
        .onReceive(roundSession.$players, perform: { _ in compute() })
    }
    
    // MARK: - Views
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 10) {
            ForEach(data, id: \.self) { d in
                HStack(spacing: 0) {
                    Text(d.player.name)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text(format == .medal ? "\(d.value.toGolfScore)" : "\(d.value)")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            
            if isTwoBall {
                HStack(spacing: 0) {
                    Text("Two ball total")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Spacer(minLength: 0)
                    
                    Text(twoBallScore)
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }
    
    // MARK: - Computation
    
    private func compute() {
        data = []
        for p in roundSession.players {
            let v = ScoringService.Stroke.calculateAccruedScore(for: p, over: session.holes, using: format)
            data.append(StrokeData(player: p, value: v))
        }
        
        data = data.sorted(by: {
            if format == .medal {
                return $0.value < $1.value
            } else {
                return $0.value > $1.value
            }
        })
        
        isTwoBall = session.stroke?.twoBall ?? false
        if isTwoBall {
            twoBallScore = ScoringService.Stroke.bestBallTotal(
                for: roundSession.players,
                over: session.holes,
                using: format
            )
        }
        
        winner = "Scores"
    }
}

struct StrokePlayResultsView_Previews: PreviewProvider {
    static var previews: some View {
        StrokePlayResultsView(session: SideGameSession())
    }
}
