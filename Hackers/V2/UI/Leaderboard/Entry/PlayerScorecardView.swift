////
////  PlayerScorecardView.swift
////  Hackers
////
////  Created by Kyle Beard on 2/23/23.
////
//
//import SwiftUI
//
//struct PlayerScorecardView: View {
//    @Environment(\.colorScheme) var colorScheme
//    @Environment(\.dismiss) var dismiss
//    
//    @EnvironmentObject var appSession: AppSession
//    @EnvironmentObject var roundSession: RoundSession
//
//    var player: Player
//    
////    @Binding var players: [Player]
////    @Binding var index: Int
////    var hole: Int
//
//    @State private var type: ScoringGridType = .front
//
//    var body: some View {
//        
//    }
//    
////    var body: some View {
////        VStack(spacing: 4) {
////            header
////                .padding(20)
////                .padding(.top, 10)
////
////            Spacer(minLength: 0)
////
////            content(for: i)
////            
//////            TabView(selection: $index) {
//////                ForEach(0..<players.count, id: \.self) { i in
//////                    content(for: i)
//////                        .tag(i)
//////                }
//////                .padding(.bottom, 20)
//////            }
//////            .tabViewStyle(.page(indexDisplayMode: .always))
//////            .onChange(of: index, perform: { _ in
//////                Haptics.fire(.light)
//////            })
////        }
////        .environmentObject(appSession)
////        .background(Color.systemViewBackground)
////        .onAppear() {
////            type = hole < 10 ? .front : .back
////            UIPageControl.appearance().pageIndicatorTintColor = colorScheme.pageIndicatorTintColor
////            UIPageControl.appearance().currentPageIndicatorTintColor = colorScheme.currentPageIndicatorTintColor
////        }
////    }
//
//    // MARK: - Content
//
////    private var header: some View {
////        ZStack {
////            BackButton(icon: .xmark, onTap: {
////                dismiss()
////                Haptics.fire(.light)
////            })
////            .alignTrailing()
////
////            Text("Scorecard")
////                .font(.dmSans, size: 20, weight: .bold)
////                .foregroundColor(Color.systemBlack)
////        }
////    }
//
////    private func content(for i: Int) -> some View {
////        VStack(spacing: 32) {
////            HStack {
////                Text(players[i].name)
////                    .font(.dmSans, size: 28, weight: .bold)
////                    .foregroundColor(players[i].color.value)
////
////                Spacer(minLength: 0)
////
////                Text(players[i].scoringSum(for: 1...18))
////                    .font(.dmSans, size: 22, weight: .bold)
////                    .foregroundColor(players[i].color.value)
////                    .padding(.vertical, 8)
////                    .padding(.horizontal, 12)
////                    .background(players[i].color.value.opacity(colorScheme.translucent))
////                    .cornerRadius(6
////                    )
////            }
////
////            scoringGrid(for: i)
////
////            Spacer(minLength: 0)
////        }
////        .padding(.horizontal, 16)
////    }
//
//    enum ScoringGridType: String {
//        case front = "Front"
//        case back = "Back"
//    }
//
//    @ViewBuilder
//    private func scoringGrid(for i: Int) -> some View {
//        let front = players[i].hasScore(in: 1...9) ? players[i].scoringSum(for: 1...9) : ""
//        let back = players[i].hasScore(in: 10...18) ? players[i].scoringSum(for: 10...18) : ""
//        
//        VStack(spacing: 16) {
//            Picker("", selection: $type) {
//                Text("Front\(front.isEmpty ? "" : " (\(front))")")
//                    .tag(ScoringGridType.front)
//                Text("Back\(back.isEmpty ? "" : " (\(back))")")
//                    .tag(ScoringGridType.back)
//            }
//            .pickerStyle(.segmented)
//            .onChange(of: type, perform: { _ in Haptics.fire(.light) })
//
//            ZStack {
//                VStack {
//                    HStack(spacing: 16) {
//                        gridTile(hole: 1 + (type == .front ? 0 : 9), for: i)
//                        Spacer(minLength: 0)
//                        gridTile(hole: 2 + (type == .front ? 0 : 9), for: i)
//                        Spacer(minLength: 0)
//                        gridTile(hole: 3 + (type == .front ? 0 : 9), for: i)
//                    }
//
//                    Divider()
//
//
//                    HStack(spacing: 16) {
//                        gridTile(hole: 4 + (type == .front ? 0 : 9), for: i)
//                        Spacer(minLength: 0)
//                        gridTile(hole: 5 + (type == .front ? 0 : 9), for: i)
//                        Spacer(minLength: 0)
//                        gridTile(hole: 6 + (type == .front ? 0 : 9), for: i)
//                    }
//
//                    Divider()
//
//                    HStack(spacing: 16) {
//                        gridTile(hole: 7 + (type == .front ? 0 : 9), for: i)
//                        Spacer(minLength: 0)
//                        gridTile(hole: 8 + (type == .front ? 0 : 9), for: i)
//                        Spacer(minLength: 0)
//                        gridTile(hole: 9 + (type == .front ? 0 : 9), for: i)
//                    }
//                }
//
//                HStack {
//                    Spacer(minLength: 0)
//                    Divider().rotationEffect(Angle(degrees: 180)).padding(.leading, -8)
//                    Spacer(minLength: 0)
//                    Divider().rotationEffect(Angle(degrees: 180)).padding(.trailing, -8)
//                    Spacer(minLength: 0)
//                }
//            }
//        }
//        .padding(16)
//        .background(Color.systemGray6)
//        .cornerRadius(8)
//    }
//
//    @ViewBuilder private func gridTile(hole: Int, for i: Int) -> some View {
//        //let score = players[i].textualScore(for: hole)
//        
//        HStack {
//            Text("\(hole)")
//                .font(.dmSans, size: 15, weight: .medium)
//                .foregroundColor(Color.systemBlack)
//
//            Spacer(minLength: 0)
//
//            Menu {
//                Button(action: { set(i: i, hole: hole, score: nil) }) {
//                    Text(PlayerScore.none.menuName)
//                }
//                Divider()
//                Group {
//                    Button(action: { set(i: i, hole: hole, score: .albatross) }) {
//                        Text(PlayerScore.albatross.menuName)
//                    }
//                    Button(action: { set(i: i, hole: hole, score: .eagle) }) {
//                        Text(PlayerScore.eagle.menuName)
//                    }
//                    Button(action: { set(i: i, hole: hole, score: .birdie) }) {
//                        Text(PlayerScore.birdie.menuName)
//                    }
//                    Button(action: { set(i: i, hole: hole, score: .par) }) {
//                        Text(PlayerScore.par.menuName)
//                    }
//                }
//                Divider()
//                Group {
//                    Button(action: { set(i: i, hole: hole, score: .bogey) }) {
//                        Text(PlayerScore.bogey.menuName)
//                    }
//                    Button(action: { set(i: i, hole: hole, score: .double) }) {
//                        Text(PlayerScore.double.menuName)
//                    }
//                    if deviceDefaults.maxScoreOverPar >= 3 {
//                        Button(action: { set(i: i, hole: hole, score: .triple) }) {
//                            Text(PlayerScore.triple.menuName)
//                        }
//                    }
//                    if deviceDefaults.maxScoreOverPar >= 4 {
//                        Button(action: { set(i: i, hole: hole, score: .quad) }) {
//                            Text(PlayerScore.quad.menuName)
//                        }
//                    }
//                    if deviceDefaults.maxScoreOverPar >= 5 {
//                        Button(action: { set(i: i, hole: hole, score: .quad) }) {
//                            Text(PlayerScore.quin.menuName)
//                        }
//                    }
//                    if deviceDefaults.maxScoreOverPar >= 6 {
//                        Button(action: { set(i: i, hole: hole, score: .sex) }) {
//                            Text(PlayerScore.sex.menuName)
//                        }
//                    }
//                }
//            } label: {
//                pickerTile(for: score)
//            }
//            .onTapGesture {
//                Haptics.fire(.light)
//            }
//            .onChange(of: players, perform: { _ in Haptics.fire(.light) })
//        }
//        .padding(4)
//    }
//
////    private func set(i: Int, hole: Int, score: PlayerScore?) {
////        Haptics.fire(.light)
////        if let s = score {
////            players[i].score[hole] = s.rawValue
////        } else {
////            players[i].score[hole] = nil
////        }
////    }
//    
//    @ViewBuilder private func
//
//    @ViewBuilder private func gridSum(range: ClosedRange<Int>, for i: Int) -> some View {
//        //let sum = players[i].scoringSum(for: range)
//        let sum = accrued(for: players[i], thru: 1)
//        Text("\(players[i].hasScore(in: range) ? sum : "-")")
//            .font(.dmSans, size: 17, weight: .bold)
//            .foregroundColor(players[i].color.value)
//    }
//    
//    private func accrued(for player: Player, thru hole: Int) -> Int {
//        let left = roundSession.holeRange.firstIndex(of: roundSession.startingHole) ?? 0
//        let right = roundSession.holeRange.firstIndex(of: hole) ?? 0
//        let range = roundSession.holeRange[left...right]
//        let score = ScoreUtil.Stroke.computeTotal(
//            for: player,
//            over: Array(range),
//            using: .medal,
//            handicaps: useHCP
//        )
//        return score
//    }
//    
//    private func pickerTile(for text: String) -> some View {
//        Text(text)
//            .font(.dmSans, size: 15, weight: .medium)
//            .foregroundColor(text == "-" ? Color.systemGray : Color.systemBlack)
//            .fixedSize(horizontal: true, vertical: false)
//            .padding(.vertical, 6)
//            .padding(.horizontal, 12)
//            .background(Color.systemViewBackground)
//            .cornerRadius(4)
//    }
//}
//
//struct PlayerScorecardView_Previews: PreviewProvider {
//    static var score: [Int: String] = [
//        1: "par",
//        2: "bogey",
//        3: "quad",
//        4: "par",
//        5: "birdie",
//        6: "triple",
//        7: "double",
//        8: "albatross",
//        9: "bogey"
//    ]
//    static var player = Player(name: "Kyle", color: .blue, score: score)
//    static var view: some View {
//        
//        PlayerScorecardView(player: player)
//        
////        VStack {
////            RoundView()
////                .sheet(isPresented: .true) {
////                    PlayerScorecardView(players: .constant([player, player]), index: .constant(0), hole: 1)
////                        .presentationDetents([.height(400)])
////                        .presentationDragIndicator(.visible)
////                }
////                .environmentObject(AppSession())
////        }
//    }
//    static var previews: some View {
//        Group {
//            view.lightModePreview()
//            view.darkModePreview()
//            view.smallDevicePreview()
//        }
//    }
//}
