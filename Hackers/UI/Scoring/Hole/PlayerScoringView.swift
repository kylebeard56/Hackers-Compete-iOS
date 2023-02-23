//
//  PlayerScoringView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/23/23.
//

import SwiftUI

struct PlayerScoringView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var players: [Player]
    @Binding var index: Int
    var hole: Int
    
//    @State private var selectedIndex: Int = 0
    
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(16)
                .padding(.top, 8)

            Spacer(minLength: 0)
            
            TabView(selection: $index) {
                ForEach(0..<players.count, id: \.self) { i in
                    ScrollView {
                        content(for: i).tag(i)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .environmentObject(appSession)
        .background(Color.systemViewBackground)
    }
    
    // MARK: - Content
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            
            Text("Scorecard")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
    }
    
    private func content(for i: Int) -> some View {
        VStack(spacing: 32) {
            HStack {
                Text(players[i].name)
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(players[i].color.value)
                
                Spacer(minLength: 0)
                
                Text(players[i].scoringSum(for: 1...18))
                    .font(.dmSans(size: 22, weight: .bold))
                    .foregroundColor(players[i].color.value)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.systemGray6)
                    .cornerRadius(4)
            }

            scoringGrid(type: hole >= 9 ? .back : .front, for: i)
            scoringGrid(type: hole >= 9 ? .front : .back, for: i)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
    
    enum ScoringGridType: String {
        case front = "Front"
        case back = "Back"
    }
    
    private func scoringGrid(type: ScoringGridType, for i: Int) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(type.rawValue)
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                Spacer(minLength: 0)
                gridSum(range: type == .front ? 1...9 : 10...18, for: i)
            }
            
            ZStack {
                VStack {
                    HStack(spacing: 16) {
                        gridTile(hole: 1 + (type == .front ? 0 : 9), for: i)
                        Spacer(minLength: 0)
                        gridTile(hole: 2 + (type == .front ? 0 : 9), for: i)
                        Spacer(minLength: 0)
                        gridTile(hole: 3 + (type == .front ? 0 : 9), for: i)
                    }
                    
                    Divider()
                    
                    
                    HStack(spacing: 16) {
                        gridTile(hole: 4 + (type == .front ? 0 : 9), for: i)
                        Spacer(minLength: 0)
                        gridTile(hole: 5 + (type == .front ? 0 : 9), for: i)
                        Spacer(minLength: 0)
                        gridTile(hole: 6 + (type == .front ? 0 : 9), for: i)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 16) {
                        gridTile(hole: 7 + (type == .front ? 0 : 9), for: i)
                        Spacer(minLength: 0)
                        gridTile(hole: 8 + (type == .front ? 0 : 9), for: i)
                        Spacer(minLength: 0)
                        gridTile(hole: 9 + (type == .front ? 0 : 9), for: i)
                    }
                }
                
                HStack {
                    Spacer(minLength: 0)
                    Divider().rotationEffect(Angle(degrees: 180)).padding(.leading, -8)
                    Spacer(minLength: 0)
                    Divider().rotationEffect(Angle(degrees: 180)).padding(.trailing, -8)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(Color.systemGray6)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func gridTile(hole: Int, for i: Int) -> some View {
        let score = players[i].textualScore(for: hole)
        HStack {
            Text("\(hole)")
                .font(.dmSans(size: 15, weight: .medium))
                .foregroundColor(Color.systemBlack)
            
            Spacer(minLength: 0)
            
            Text("\(score)")
                .font(.dmSans(size: 15, weight: .medium))
                .foregroundColor(score == "-" ? Color.systemGray : Color.systemBlack)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.systemViewBackground)
                .cornerRadius(4)
        }
        .padding(4)
    }
    
    @ViewBuilder
    private func gridSum(range: ClosedRange<Int>, for i: Int) -> some View {
        let sum = players[i].scoringSum(for: range)
        Text("\(players[i].hasScore(in: range) ? sum : "-")")
            .font(.dmSans(size: 17, weight: .bold))
            .foregroundColor(players[i].color.value)
    }
    
    /**
     Picker("", selection: $selectedScore) {
         Group {
             Text(PlayerScore.none.name).tag(PlayerScore.none)
             Divider()
             Text(PlayerScore.albatross.name).tag(PlayerScore.albatross)
             Text(PlayerScore.eagle.name).tag(PlayerScore.eagle)
             Text(PlayerScore.birdie.name).tag(PlayerScore.birdie)
             Divider()
         }
         Group {
             Text(PlayerScore.par.name).tag(PlayerScore.par)
             Divider()
             Text(PlayerScore.bogey.name).tag(PlayerScore.bogey)
             Text(PlayerScore.double.name).tag(PlayerScore.double)
             Text(PlayerScore.triple.name).tag(PlayerScore.triple)
             Text(PlayerScore.quad.name).tag(PlayerScore.quad)
         }
     }
     .scaleEffect(0.9)
     .pickerStyle(.menu)
     .tint(Color.systemBlack.opacity(menuOpacity))
     .background(Color.systemGray6)
     .cornerRadius(4)
     .onTapGesture {
         Haptics.fire(.light)
     }
     **/
    
//    private var frontNine: some View {
//        ZStack {
//            VStack {
//                Text("Front")
//                    .font(.dmSans(size: 15, weight: .medium))
//                    .foregroundColor(Color.systemBlack)
//                    .alignCenter()
//
//                HStack(spacing: 8) {
//                    gridTile(hole: 1)
//                    Spacer(minLength: 0)
//                    gridTile(hole: 6)
//                }
//
//                HStack(spacing: 8) {
//                    gridTile(hole: 2)
//                    Spacer(minLength: 0)
//                    gridTile(hole: 7)
//                }
//
//                HStack(spacing: 8) {
//                    gridTile(hole: 3)
//                    Spacer(minLength: 0)
//                    gridTile(hole: 8)
//                }
//
//                HStack(spacing: 8) {
//                    gridTile(hole: 4)
//                    Spacer(minLength: 0)
//                    gridTile(hole: 9)
//                }
//
//                HStack(spacing: 8) {
//                    gridTile(hole: 5)
//                    Spacer(minLength: 0)
//                    gridSum(range: 1...9)
//                }
//
//                Spacer(minLength: 0)
//            }
//
//            HStack {
//                Spacer()
//                Rectangle()
//                    .fill(Color.systemGray4)
//                    .frame(width: 1)
//                    .padding(.top, 32)
//                Spacer()
//            }
//        }
//        .padding(12)
//        .background(Color.systemGray6)
//        .cornerRadius(8)
//    }
}

struct PlayerScoringView_Previews: PreviewProvider {
    static var score: [Int: String] = [
        1: "par",
        2: "bogey",
        3: "quad",
        4: "par",
        5: "birdie",
        6: "triple",
        7: "double",
        8: "albatross",
        9: "bogey"
    ]
    static var player = Player(name: "Kyle", color: .blue, difficulty: .easy, redrawCount: 3, score: score)
    static var view: some View {
        VStack {
            RoundView()
                .sheet(isPresented: .true) {
                    PlayerScoringView(players: .constant([player, player]), index: .constant(0), hole: 1)
                        .presentationDetents([.height(375), .large])
                        .presentationDragIndicator(.visible)
                }
                .environmentObject(AppSession())
        }
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
