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
                VStack(spacing: 0) {
                    Text(result.name)
                        .font(.dmSans(size: 28, weight: .bold))
                        .foregroundColor(result.color)
                        .alignLeading()
                    
                    Text("\(result.difficulty.label) difficulty")
                        .font(.dmSans(size: 12, weight: .medium))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                }

                Spacer()
                
                Text(result.scoreTotal.toGolfScore)
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(result.color)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.systemGray6.opacity(0.5))
                    .cornerRadius(4)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                VStack(spacing: 6) {
                    Text("Favor Cards")
                        .font(.dmSans(size: 12, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    HStack(spacing: 4) {
                        Text("\(result.scoreFavor.toGolfScore)")
                            .font(.dmSans(size: 20, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                        Text("over \(result.favorCards) holes")
                            .font(.dmSans(size: 12, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                            .padding(.top, 4)
                        Spacer()
                    }
                }
                .padding(12)
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
                            .foregroundColor(Color.systemBlack)
                        Text("over \(result.challengeCards) holes")
                            .font(.dmSans(size: 12, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                            .padding(.top, 4)
                        Spacer()
                    }
                }
                .padding(12)
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
                    
                    Text("Over \(result.holesScored) holes, we can breakdown your score to see average scoring margin against par.")
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
                
                Text("We can also view your best and worst scores over the round.")
                    .font(.dmSans(size: 15, weight: .regular))
                    .foregroundColor(Color.systemGray)
                    .alignLeading()
                    .multilineTextAlignment(.leading)
                
                minMaxTile
                
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
                    
                    groupedScoringScroller
                    
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
                FirebaseEvent.playerSummaryExpanded.log()
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
            modifiedScorecard = result.scorecard//.filter({ !($0.0 == .none && $0.1 == .none) })
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
    
    private var groupedScoringScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Text("")
                if result.albatrossCount != 0 {
                    tile(text: PlayerScore.albatross.numberName, value: "\(result.albatrossCount)")
                        .frame(minWidth: 64)
                }
                if result.eagleCount != 0 {
                    tile(text: PlayerScore.eagle.numberName, value: "\(result.eagleCount)")
                        .frame(minWidth: 64)
                }
                if result.birdieCount != 0 {
                    tile(text: PlayerScore.birdie.numberName, value: "\(result.birdieCount)")
                        .frame(minWidth: 64)
                }
                if result.parCount != 0 {
                    tile(text: PlayerScore.par.numberName, value: "\(result.parCount)")
                        .frame(minWidth: 64)
                }
                if result.bogeyCount != 0 {
                    tile(text: PlayerScore.bogey.numberName, value: "\(result.bogeyCount)")
                        .frame(minWidth: 64)
                }
                if result.doubleCount != 0 {
                    tile(text: PlayerScore.double.numberName, value: "\(result.doubleCount)")
                        .frame(minWidth: 64)
                }
                if result.tripleCount != 0 {
                    tile(text: PlayerScore.triple.numberName, value: "\(result.tripleCount)")
                        .frame(minWidth: 64)
                }
                if result.quadCount != 0 {
                    tile(text: PlayerScore.quad.numberName, value: "\(result.quadCount)")
                        .frame(minWidth: 64)
                }
                Text("")
            }
        }
        .padding(.horizontal, -16)
        .padding(.vertical, 16)
    }
    
    private var minMaxTile: some View {
        ZStack {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("")
                        .font(.dmSans(size: 13, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                        .frame(width: 64)
                    Text("Favor")
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("Challenge")
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    Text("Best")
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                        .frame(width: 64)
                    Text("\(result.minFavor.shortName)")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(result.minChallenge.shortName)")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    Text("Worst")
                        .font(.dmSans(size: 13, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                        .frame(width: 64)
                    Text("\(result.maxFavor.shortName)")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(result.maxChallenge.shortName)")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
            }
            HStack {
                Spacer().frame(width: 64)
                Rectangle()
                    .frame(width: 1)
                Spacer()
                Rectangle()
                    .frame(width: 1)
                Spacer()
            }
            .foregroundStyle(Color.systemGray4)
        }
        .padding(16)
        .background(Color.systemGray6.opacity(0.5))
        .cornerRadius(8)
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
        challengeDifferential: 1,
        minFavor: .birdie,
        maxFavor: .bogey,
        minChallenge: .par,
        maxChallenge: .triple,
        albatrossCount: 0,
        eagleCount: 0,
        birdieCount: 2,
        parCount: 4,
        bogeyCount: 4,
        doubleCount: 3,
        tripleCount: 2,
        quadCount: 0
    )
    
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
