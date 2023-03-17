//
//  ScoringRow.swift
//  Hackers
//
//  Created by Kyle Beard on 2/17/23.
//

import SwiftUI

enum PlayerScore: String {
    case albatross, eagle, birdie, par, bogey, double, triple, quad, none
    
    var name: String {
        switch self {
        case .albatross:    return "Albatross"
        case .eagle:        return "Eagle"
        case .birdie:       return "Birdie"
        case .par:          return "Par"
        case .bogey:        return "Bogey"
        case .double:       return "Double Bogey"
        case .triple:       return "Triple Bogey"
        case .quad:         return "Quadruple Bogey"
        case .none:         return "Enter score"
        }
    }
    
    var shortName: String {
        switch self {
        case .albatross:    return "Albatross"
        case .eagle:        return "Eagle"
        case .birdie:       return "Birdie"
        case .par:          return "Par"
        case .bogey:        return "Bogey"
        case .double:       return "Double"
        case .triple:       return "Triple"
        case .quad:         return "Quad"
        case .none:         return "-"
        }
    }
    
    var numberName: String {
        switch self {
        case .albatross:    return "# of Albatrosses"
        case .eagle:        return "# of Eagles"
        case .birdie:       return "# of Birdies"
        case .par:          return "# of Pars"
        case .bogey:        return "# of Bogeys"
        case .double:       return "# of Doubles"
        case .triple:       return "# of Triples"
        case .quad:         return "# of Quads"
        case .none:         return "# of Skipped"
        }
    }
    
    var menuName: String {
        switch self {
        case .albatross:    return "Albatross (-3)"
        case .eagle:        return "Eagle (-2)"
        case .birdie:       return "Birdie (-1)"
        case .par:          return "Par (0)"
        case .bogey:        return "Bogey (+1)"
        case .double:       return "Double Bogey (+2)"
        case .triple:       return "Triple Bogey (+3)"
        case .quad:         return "Quadruple Bogey (+4)"
        case .none:         return "Enter score"
        }
    }
    
    var numericalValue: Int {
        switch self {
        case .albatross:    return -3
        case .eagle:        return -2
        case .birdie:       return -1
        case .par:          return 0
        case .bogey:        return 1
        case .double:       return 2
        case .triple:       return 3
        case .quad:         return 4
        case .none:         return 0
        }
    }
    
    var maxValue: Int {
        switch self {
        case .albatross:    return -3
        case .eagle:        return -2
        case .birdie:       return -1
        case .par:          return 0
        case .bogey:        return 1
        case .double:       return 2
        case .triple:       return 3
        case .quad:         return 4
        case .none:         return 5
        }
    }
}

struct ScoringRow: View {
    @Binding var player: Player
    var currentHole: Int
    var showTotal: Bool = false
    
    @State private var currentScore: String = ""
    @State private var scoreColor: Color = .systemGrayDark
    @State private var menuOpacity: CGFloat = 0.69
    
    @State private var selectedScore: PlayerScore = .none
    
    var body: some View {
        HStack {
//            Circle()
//                .fill(player.color.value)
//                .frame(width: 8, height: 8)
//
            Text(player.name)
                .font(.dmSans(size: 20, weight: .medium))
                .foregroundColor(player.color.value)

            Spacer()
            
            Menu {
                Button(action: { set(score: .none) }) {
                    Text(PlayerScore.none.menuName)
                }
                Divider()
                Group {
                    Button(action: { set(score: .albatross) }) {
                        Text(PlayerScore.albatross.menuName)
                    }
                    Button(action: { set(score: .eagle) }) {
                        Text(PlayerScore.eagle.menuName)
                    }
                    Button(action: { set(score: .birdie) }) {
                        Text(PlayerScore.birdie.menuName)
                    }
                    Button(action: { set(score: .par) }) {
                        Text(PlayerScore.par.menuName)
                    }
                }
                Divider()
                Group {
                    Button(action: { set(score: .bogey) }) {
                        Text(PlayerScore.bogey.menuName)
                    }
                    Button(action: { set(score: .double) }) {
                        Text(PlayerScore.double.menuName)
                    }
                    Button(action: { set(score: .triple) }) {
                        Text(PlayerScore.triple.menuName)
                    }
                    Button(action: { set(score: .quad) }) {
                        Text(PlayerScore.quad.menuName)
                    }
                }
            } label: {
                Text(selectedScore.menuName)
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(selectedScore == .none ? Color.systemGray : Color.systemBlack)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.systemGray6)
                    .cornerRadius(4)
                    .alignTrailing()
            }
            .onTapGesture {
                Haptics.fire(.light)
            }
            
//            Picker("", selection: $selectedScore) {
//                Group {
//                    Text(PlayerScore.none.name).tag(PlayerScore.none)
//                    Divider()
//                    Text(PlayerScore.albatross.name).tag(PlayerScore.albatross)
//                    Text(PlayerScore.eagle.name).tag(PlayerScore.eagle)
//                    Text(PlayerScore.birdie.name).tag(PlayerScore.birdie)
//                    Divider()
//                }
//                Group {
//                    Text(PlayerScore.par.name).tag(PlayerScore.par)
//                    Divider()
//                    Text(PlayerScore.bogey.name).tag(PlayerScore.bogey)
//                    Text(PlayerScore.double.name).tag(PlayerScore.double)
//                    Text(PlayerScore.triple.name).tag(PlayerScore.triple)
//                    Text(PlayerScore.quad.name).tag(PlayerScore.quad)
//                }
//            }
//            .scaleEffect(0.9)
//            .pickerStyle(.menu)
//            .tint(Color.systemBlack.opacity(menuOpacity))
//            .background(Color.systemGray6)
//            .cornerRadius(4)
//            .onTapGesture {
//                Haptics.fire(.light)
//            }
            
            if showTotal {
                Text(currentScore)
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(scoreColor)
                    .frame(width: 56)
            }
        }
        .onAppear() {
            selectedScore = PlayerScore(rawValue: player.score[currentHole] ?? "") ?? .none
            calculateScore()
        }
        .onChange(of: player, perform: { _ in
            selectedScore = PlayerScore(rawValue: player.score[currentHole] ?? "") ?? .none
            calculateScore()
        })
        .onChange(of: selectedScore, perform: { s in
            player.score[currentHole] = s.rawValue
            menuOpacity = selectedScore == .none ? 0.4 : 1.0
            calculateScore()
        })
    }
    
    private func set(score: PlayerScore) {
        Haptics.fire(.light)
        selectedScore = score
    }
    
    private func calculateScore() {
        var score: Int = 0
        for value in player.score.values {
            let v = PlayerScore(rawValue: value) ?? .par
            score += v.numericalValue
        }
        
        if score == 0 {
            currentScore = "E"
        } else {
            currentScore = "\(score > 0 ? "+" : "")\(score)"
        }
        
        scoreColor = score < 0 ? .systemRed : score > 0 ? .systemGrayDark : .systemGreen
    }
}

struct ScoringRow_Previews: PreviewProvider {
    static let p1: Binding<Player> = .constant(
        Player(name: "Kyle", score: [1: "par", 2: "bogey", 3: "double"])
    )
    static let p2: Binding<Player> = .constant(
        Player(name: "Santiago", score: [1: "eagle", 2: "triple", 3: "birdie"])
    )
    static let p3: Binding<Player> = .constant(
        Player(name: "Andrew", score: [1: "birdie", 2: "birdie", 3: "par"])
    )
    static let p4: Binding<Player> = .constant(
        Player(name: "Blake", score: [1: "quad", 2: "quad", 3: "quad"])
    )
    
    static var view: some View {
        VStack(spacing: 16) {
            ScoringRow(player: p1, currentHole: 1)
            ScoringRow(player: p2, currentHole: 1)
            ScoringRow(player: p3, currentHole: 1)
            ScoringRow(player: p4, currentHole: 1)
        }
        .padding(.horizontal, 16)
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
