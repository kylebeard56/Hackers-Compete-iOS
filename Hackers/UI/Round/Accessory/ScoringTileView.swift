//
//  ScoringTileView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/28/23.
//

import SwiftUI

struct ScoringTileView: View {
    @StateObject var viewModel: RoundViewModel
    var hole: Int
    
    @State private var selectedPlayer: Player = Player()
    @State private var selectedIndex: Int = 0
    
    @State private var showHoleDetail: Bool = false
    @State private var showHoleScoring: Bool = false
    @State private var showPlayerScoring: Bool = false
    
    var body: some View {
        content
            .padding(16)
            .background(Color.systemGray6)
            .cornerRadius(8)
            .border(Color.systemGray5, width: 1, cornerRadius: 8)
            .sheet(isPresented: $showHoleDetail) {
                HoleDetailView(viewModel: viewModel, hole: hole)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showHoleScoring) {
                HoleScoringView(players: $viewModel.players, hole: hole)
                    .presentationDetents([.height(viewModel.holeScoringHeight)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPlayerScoring) {
                PlayerScoringView(players: $viewModel.players, index: $selectedIndex, hole: hole)
                    .presentationDetents([.height(436)])
                    .presentationDragIndicator(.visible)
            }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: {
                    Haptics.fire(.light)
                    showHoleScoring = true
                    FirebaseEvent.addScoreTapped.log()
                }) {
                    HStack(spacing: 16) {
                        Text("Scorecard")
                            .font(.dmSans(size: 17, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                        
                        AwesomeImage(
                            icon: viewModel.scoringExists(for: hole) ? .penSquare : .squarePlus,
                            style: .regular,
                            size: 17,
                            color: .systemBlack
                        )
                    }
                }
                
                Spacer(minLength: 0)
                
                Button(action: {
                    Haptics.fire(.light)
                    self.showHoleDetail = true
                    // TODO: Firebase analytics
                }) {
                    if let d = viewModel.holeDetails[hole] {
                        Text("Par \(d.par)")
                            .font(.dmSans(size: 15, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.systemGray5)
                            .cornerRadius(6)
                    } else {
                        AwesomeImage(icon: .golfFlagHole, style: .regular, size: 17, color: .systemBlack)
                    }
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Spacer().frame(width: 8)
                    ForEach(viewModel.players, id: \.self) { player in
                        Button(action: {
                            selectedPlayer = player
                            selectedIndex = viewModel.players.firstIndex(where: { $0.id == player.id }) ?? 0
                            showPlayerScoring = true
                            Haptics.fire(.light)
                        }) {
                            scoringTile(for: player)
                        }
                    }
                    Spacer().frame(width: 8)
                }
                .frame(minWidth: UIScreen.main.bounds.width - 24)
            }
            .padding(.horizontal, -16)
        }
    }
    
    private func scoringTile(for p: Player) -> some View {
        VStack(spacing: 6) {
            Text(p.name)
                .font(.dmSans(size: 13, weight: .medium))
                .foregroundColor(p.color.value)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .alignLeading()
            
            HStack(spacing: 4) {
                let score = p.textualScore(for: hole)
                if score == "-" {
                    Text("-")
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemGray3)
                        .padding(.top, 7)
                } else {
                    Text(score)
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                }
                    
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.systemCard)
        .border(Color.systemGray5, width: 2, cornerRadius: 12)
        .cornerRadius(12)
//        .padding(8)
//        .background(Color.systemCard)
//        .border(Color.systemGray5, width: 2, cornerRadius: 6)
//        .cornerRadius(6)
    }
}

struct ScoringTileView_Previews: PreviewProvider {
    static var previews: some View {
        ScoringTileView(viewModel: RoundViewModel(), hole: 1)
    }
}
