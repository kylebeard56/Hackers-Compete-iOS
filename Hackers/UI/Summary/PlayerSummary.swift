//
//  PlayerSummary.swift
//  Hackers
//
//  Created by Kyle Beard on 2/18/23.
//

import SwiftUI

struct PlayerSummary: View {
    var result: PlayerResult
    var place: Int
    
    @State private var modifiedScorecard: [PlayerScoreDifficultyPair] = []
    @State private var expand: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {            
            HStack(spacing: 8) {
                if place == 1 {
                    Image(systemName: "trophy.circle")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundColor(Color.systemYellow)
                } else {
                    Image(systemName: "\(place).circle")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                }

                VStack(spacing: 0) {
                    Text(result.name)
                        .font(.dmSans(size: 28, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("\(result.difficulty.label)")
                        .font(.dmSans(size: 12, weight: .medium))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                }

                Spacer()
                
                Text(result.scoreTotal.toGolfScore)
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(result.scoreTotal.toGolfColorInverted)
                    .padding(8)
                    .padding(.horizontal, result.scoreTotal == 0 ? 8 : 0)
                    .background(Color.systemBlack.opacity(0.85))
                    .border(Color.systemBlack, width: 2, cornerRadius: 6)
                    .cornerRadius(6)
            }
            
            HStack(alignment: .bottom, spacing: 16) {
                VStack(spacing: 6) {
                    Text("Favor Cards")
                        .font(.dmSans(size: 12, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    HStack(spacing: 4) {
                        Text("\(result.scoreFavor.toGolfScore)")
                            .font(.dmSans(size: 20, weight: .bold))
                            .foregroundColor(result.scoreFavor.toGolfColor)
                        Text("over \(result.favorCards) holes")
                            .font(.dmSans(size: 12, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                            .padding(.top, 4)
                        Spacer()
                    }
                }
                .padding(8)
                .background(Color.systemGray6.opacity(0.5))
                .border(Color.systemGray6, width: 2, cornerRadius: 6)
                .cornerRadius(6)
                
                VStack(spacing: 6) {
                    Text("Challenge Cards")
                        .font(.dmSans(size: 12, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    HStack {
                        Text("\(result.scoreChallenge.toGolfScore)")
                            .font(.dmSans(size: 20, weight: .bold))
                            .foregroundColor(result.scoreChallenge.toGolfColor)
                        Text("over \(result.challengeCards) holes")
                            .font(.dmSans(size: 12, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                            .padding(.top, 4)
                        Spacer()
                    }
                }
                .padding(8)
                .background(Color.systemGray6.opacity(0.5))
                .border(Color.systemGray6, width: 2, cornerRadius: 6)
                .cornerRadius(6)
            }
            
            if expand {
                PillDivider()
                    .padding(.vertical, 16)
                
                VStack(spacing: 4) {
                    Text("Scoring Differentials")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Over \(result.holesScored) holes, we can breakdown your \(result.scoreTotal.toGolfScore) score to see your average scoring differential per hole against par.")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                        .multilineTextAlignment(.leading)
                }
                
                HStack(alignment: .bottom, spacing: 16) {
                    tile(text: "Raw", value: "\(result.differential.toGolfDiff)", size: 20)
                    tile(text: "Favor", value: "\(result.favorDifferential.toGolfDiff)", size: 20)
                    tile(text: "Challenge", value: "\(result.challengeDifferential.toGolfDiff)", size: 20)
                }
                
                PillDivider()
                    .padding(.vertical, 16)
                
                VStack(spacing: 4) {
                    Text("Scorecard")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Take a trip down memory lane to see your results on each hole and what could have influenced your outcome.")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                        .multilineTextAlignment(.leading)
                    
                    Divider()
                        .padding(.vertical, 8)
                    ForEach(1..<modifiedScorecard.count + 1, id: \.self) { i in
                        let sc = modifiedScorecard[i-1]
                        HStack(spacing: 16) {
                            Text("Hole \(i)")
                                .font(.dmSans(size: 15, weight: .medium))
                                .foregroundColor(Color.systemBlack)
                            Spacer()
                            
                            Text("\(sc.0 == .none ? "Not scored" : sc.0.name)")
                                .font(.dmSans(size: 15, weight: .regular))
                                .foregroundColor(sc.0 == .none ? Color.systemGray : Color.systemBlack)
                            
                            AwesomeImage(icon: sc.1.icon, style: .regular, size: 15, color: sc.1.color)
                                .frame(width: 24)
                        }
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
            }
            
            Button(action: {
                withAnimation(.linear(duration: 0.2)) {
                    expand.toggle()
                }
            }) {
                Text("\(expand ? "Show less" : "Show more") for \(result.name)")
                    .font(.dmSans(size: 12, weight: .bold))
                    .foregroundColor(result.color)
                    .alignCenter()
            }
        }
        .padding(16)
        .background(Color.systemCard)
        .cornerRadius(8)
        .onAppear() {
            // Filter out any non-scored or non-played holes
            modifiedScorecard = result.scorecard.filter({ !($0.0 == .none && $0.1 == .none) })
        }
    }
    
    private func tile(text: String, value: String, color: Color = .systemBlack, size: CGFloat = 28) -> some View {
        VStack(spacing: 6) {
            Text(text)
                .font(.dmSans(size: 12, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            Text(value)
                .font(.dmSans(size: size, weight: .bold))
                .foregroundColor(color)
                .alignLeading()
        }
        .padding(8)
        .background(Color.systemGray6.opacity(0.5))
        .border(Color.systemGray6, width: 2, cornerRadius: 6)
        .cornerRadius(6)
    }
    
    private var placeEnding: String {
        switch place {
        case 1:     return "ST"
        case 2:     return "ND"
        case 3:     return "RD"
        case 4:     return "TH"
        default:    return ""
        }
    }
}

struct PlayerSummary_Previews: PreviewProvider {
    static let r = PlayerResult(
        name: "Kyle",
        color: .systemBlue,
        difficulty: .medium,
        holesScored: 18,
        totalCards: 18,
        favorCards: 11,
        challengeCards: 9,
        scorecard: [
            (PlayerScore.birdie, RuleDifficulty.favor),
            (PlayerScore.par, RuleDifficulty.challenge),
            (PlayerScore.par, RuleDifficulty.challenge),
            (PlayerScore.bogey, RuleDifficulty.favor),
            (PlayerScore.triple, RuleDifficulty.challenge),
            (PlayerScore.double, RuleDifficulty.favor),
            (PlayerScore.bogey, RuleDifficulty.challenge),
            (PlayerScore.bogey, RuleDifficulty.favor),
            (PlayerScore.birdie, RuleDifficulty.favor),
        ],
        scoreTotal: 15,
        scoreFavor: 6,
        scoreChallenge: 9,
        differential: 0.833,
        favorDifferential: 0.545,
        challengeDifferential: 1)
    
    static var view: some View {
        VStack {
            ScrollView {
                PlayerSummary(result: r, place: 1)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.systemGray6)
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
