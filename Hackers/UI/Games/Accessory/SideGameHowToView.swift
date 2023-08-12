//
//  SideGameHowToView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/17/23.
//

import SwiftUI

struct SideGameHowToView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var game: SideGame
    
    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                    .alignTop()
            }
            .padding(.top, 10)
            .padding(.vertical, 10)
            .navigationTitle(game.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
//                        .padding(.trailing, 4)
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
        }
        .background(Color.systemViewBackground)
        .padding(.top, 10)
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            
            // TODO: Hackers classic stamp for games made by hackers
            // TODO: Info banner for skins or two ball formats available
            
            infoBox
            
            VStack(spacing: 4) {
                Text("Overview")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Text(LocalizedStringKey(overviewText))
                    .font(.dmSans(size: 17, weight: .regular))
                    .foregroundColor(Color.systemBlack)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
                    .lineSpacing(2)
            }
            
            VStack(spacing: 4) {
                Text("Rules")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Text(LocalizedStringKey(rulesText))
                    .font(.dmSans(size: 17, weight: .regular))
                    .foregroundColor(Color.systemBlack)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
                    .lineSpacing(2)
            }
            
            if game == .stableford {
                stablefordScoringGrid
            }
            
            if game == .fibonacci {
                fibonacciScoringGrid
            }
            
            if game == .nines {
                ninesScoringGrid
            }
        }
    }
    
    // MARK: - Info box + components
    
    private var infoBox: some View {
        VStack(spacing: 12) {
            row(title: "Players", value: game.playerLabel)
            
            HStack {
                Text("Complexity to learn")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                complexityCircles(for: game.complexity)
            }
            
            row(title: "Individual or team", value: game.structure.rawValue)
            row(title: "Pace of play", value: game.pace.rawValue)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .border(
            colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
            width: 2,
            cornerRadius: 12
        )
    }
    
    @ViewBuilder private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
            
            Text(value)
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(Color.systemHackersPurple)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
    
    private func complexityCircles(for level: SideGameComplexity) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.systemHackersPurple)
                .frame(width: 8, height: 8)
            
            Circle()
                .fill(
                    level == .medium || level == .high
                    ? Color.systemHackersPurple
                    : colorScheme.isLight
                    ? Color.systemGray5
                    : Color.systemGray2
                )
                .frame(width: 8, height: 8)
            
            Circle()
                .fill(
                    level == .high
                    ? Color.systemHackersPurple
                    : colorScheme.isLight
                    ? Color.systemGray5
                    : Color.systemGray2
                )
                .frame(width: 8, height: 8)
        }
    }
    
    // MARK: - Overview
    
    private var overviewText: String {
        switch game {
        case .banker:
            return "With a similar structure to Blackjack, this game is great for parties looking for competitive wagers against everyone else on each hole."
        case .bestBall:
            return "Also known as *Match Play*, this game is great for dueling when you don't care about margin of victory. Skins format available.."
        case .bingoBangoBongo:
            return "This game is perfect for parties wanting a side game without the hassle, where you can only score points around the green."
        case .cardsOfChaos:
            return "Your party will draw amusing cards for each hole that dictate how each player can and cannot play the hole."
        case .fibonacci:
            return "This game scores stroke play with a twist on nature's golden number where better scoring is rewarded exponentially."
        case .football:
            return "For foursomes, this game features 2v2 play where teams strategically battle over multiple holes to score touchdowns, field goals, and safeties."
        case .hammer:
            return "This game is played as 1v1 or 2v2 and features unlimited, spontaneous doubling of stakes of each hole. Tread lightly!"
        case .hotPotato:
            return "This game tosses a hot potato to player(s) on each hole. If you're holding the potato, your score can be multiplied 2-4x."
        case .medalPlay:
            return "Also known as *Stroke Play*, this game is the most common version of golf where each stroke counts. Two ball format available."
        case .monkeyInTheMiddle:
            return "For parties of 3, the player with the middle distance shot off the tee doubles their score and battles the rest of the party."
        case .nines:
            return "For parties of 3, nine points are up for grabs on each hole and are split between the party based on scoring outcomes."
        case .stableford:
            return "Stableford is a great format for parties of all sizes and skills with a forgiving scoring system that rewards aggressive play."
        case .survivor:
            return "This game assigns each player a number of lives that are gained and lost according to scoring outcomes. Last one standing wins!"
        case .vegas:
            return "For foursomes with balanced skillset, this game features 2v2 play where scores on each hole are combined in a fun format."
        case .wolfHammer:
            return "Made famous by the No Laying Up podcast, this game features intense strategy and dangerously spontaneous wagers. Beware!"
        case .none:
            return "Yet to be written"
        }
    }
    
    // MARK: - Rules
    
    private var rulesText: String {
        switch game {
        case .banker:
            return "Yet to be written"
        case .bestBall:
            return "Yet to be written"
        case .bingoBangoBongo:
            return "Each hole has 3 points up for grabs. The first player to reach the green (**Bingo**) get 1 point. Then, once all players are on the green, the closest to the pin (**Bango**) get 1 point. Lastly, whichever player makes the longest putt (**Bongo**) gets 1 point.\n\nYour party has the freedom to decide how any tiebreaks will be settled. Get creative and have fun!"
        case .cardsOfChaos:
            return "Yet to be written"
        case .fibonacci:
            return "Teams or players will play each hole like stroke play and earn points based on their strokes. The scoring format follows the Fibonacci sequence which simply says that a number is the sum of the two numbers before it. The highest score at the end of the game is the winner."
        case .football:
            return "Yet to be written"
        case .hammer:
            return "Yet to be written"
        case .hotPotato:
            return "Yet to be written"
        case .medalPlay:
            return "Players will play their own ball for the entirely of each hole. The sum of strokes on each hole will be the player's score with the lowest score being the winner overall. Refer to the [USGA Rules](https://www.usga.org/rules/rules-and-clarifications/rules-and-clarifications.html#!ruletype=fr&section=rule&rulenum=1) if you're curious."
        case .monkeyInTheMiddle:
            return "Yet to be written"
        case .nines:
            return "Every hole gives four different scenarios for players to earn 9 points depending on scoring outcomes:"
        case .stableford:
            return "Teams or players will play each hole like stroke play and earn points based on their strokes. The scoring format follows the Stableford system which only rewards points when players bogey or better. The highest score at the end of the game is the winner."
        case .survivor:
            return "Yet to be written"
        case .vegas:
            return "Each player on the team will play their own ball. When the hole is complete, the Vegas score will be computed by multiplying the lowest score by 10 and then adding it to the highest score. Examples:\n\nA team shoots a bogey (+1) and double (+2). Since a bogey is best, this score is 10x so\n(1 x 10) + 2 = 12.\n\nA team shoots a birdie (-1) and triple (+3). Since a birdie is best, this score is 10x so\n(-1 x 10) + 3 = -7.\n\nA team shoots an eagle (-2) and birdie (-1). Since an eagle is best, this score is 10x so\n(-2 x 10) + (-1) = -21.\n\nThe important trend here is your team can remain competitive as long as one player scores well. At the end of the game, the team with the fewest total points wins."
        case .wolfHammer:
            return "Yet to be written"
        case .none:
            return "Yet to be written"
        }
    }
    
    // MARK: - Scoring grids
    
    @ViewBuilder private var stablefordScoringGrid: some View {
        let scores: [PlayerScore] = [.albatross, .eagle, .birdie, .par, .bogey]
        
        VStack(spacing: 10) {
            row(title: "SCORE", value: "POINTS")
            Divider()
            ForEach(scores, id: \.self) { s in
                row(title: s.name, value: "\(s.stablefordValue)")
            }
            row(title: "Everything else", value: "0")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .border(
            colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
            width: 2,
            cornerRadius: 12
        )
    }
    
    @ViewBuilder private var fibonacciScoringGrid: some View {
        let scores: [PlayerScore] = [.albatross, .eagle, .birdie, .par, .bogey, .double, .triple, .quad]
        
        VStack(spacing: 10) {
            row(title: "SCORE", value: "POINTS")
            Divider()
            ForEach(scores, id: \.self) { s in
                row(title: s.name, value: "\(s.fibonacciValue)")
            }
            row(title: "Everything else", value: "0")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .border(
            colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
            width: 2,
            cornerRadius: 12
        )
    }
    
    @ViewBuilder private var ninesScoringGrid: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                row(title: "Scenario 1", value: "Clear winner and no ties")
                Divider()
                row(title: "1st", value: "5")
                row(title: "2nd", value: "3")
                row(title: "3rd", value: "1")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .border(
                colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
                width: 2,
                cornerRadius: 12
            )
            
            VStack(spacing: 10) {
                row(title: "Scenario 2", value: "Tie for 1st")
                Divider()
                row(title: "T-1st", value: "4")
                row(title: "T-1st", value: "4")
                row(title: "3rd", value: "1")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .border(
                colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
                width: 2,
                cornerRadius: 12
            )
            
            VStack(spacing: 10) {
                row(title: "Scenario 3", value: "Tie for 2nd")
                Divider()
                row(title: "1st", value: "5")
                row(title: "T-2nd", value: "2")
                row(title: "T-2nd", value: "2")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .border(
                colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
                width: 2,
                cornerRadius: 12
            )
            
            VStack(spacing: 10) {
                row(title: "Scenario 4", value: "Everyone tied")
                Divider()
                row(title: "1st", value: "3")
                row(title: "2nd", value: "3")
                row(title: "3rd", value: "3")
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .border(
                colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
                width: 2,
                cornerRadius: 12
            )
        }
    }
}

struct SideGameHowToView_Previews: PreviewProvider {
    static var previews: some View {
        SideGameHowToView(game: .nines)
            .holisticPreview()
    }
}
