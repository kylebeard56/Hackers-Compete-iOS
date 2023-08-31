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
        VStack(spacing: 0) {
            ZStack {
                Text(game.name)
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 2)
                    .alignTop()
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(Color.systemViewBackground)
    }
    
    private var content: some View {
        VStack(spacing: 20) {
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
            return "Hut, hut, hike! Battle for possession to score touchdowns or field goals in this pigskin take on best ball."
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
            return "Everyplayer starts with a set number of lives that are gained and lost according to scoring outcomes. Last one standing wins!"
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
            return "On each hole, a player is designated as the *banker* to play simultaneous 1v1 matches with the rest of the players in the party. On the first tee, the banker is chosen by the party. After the first hole, the banker is always the player with the lowest score on the previous hole (tiebreak is longest putt made).\n\nOn the tee, the players each pick a wager for their individual match with the banker. The minimum wager is 5 points and the maximum wager is chosen by the banker on each hole, up to 100 points. All players will then hit their tee shots, with the banker teeing off last.\n\nAfter the players tee off, they can individually decide to press their bet, doubling their wager for the match. All presses must be made before the banker tees. Once the banker tees, they can press back, but must press everyone.\n\nOn Par 3s, all presses must be called while the ball is in flight and wagers are tripled instead of doubled.\n\nAt the end of the game, players in the negative will be indebted to those in the positive! Good luck and play responsibly!"
        case .bestBall:
            return "Players will play their own ball for the entirely of each hole. However, unlike stroke play, this format is gives 1 point to whichever player or team had the lowest score on that hole. In the event of ties, the party has the option to enable *skins* format, where points rollover to the next hole. This format is great for parties that want to battle aggressively on each hole as it eliminates the lingering effects of a lopsided stroke margin of victory."
        case .bingoBangoBongo:
            return "Each hole has 3 points up for grabs. The first player to reach the green (**Bingo**) get 1 point. Then, once all players are on the green, the closest to the pin (**Bango**) get 1 point. Lastly, whichever player makes the longest putt (**Bongo**) gets 1 point.\n\nYour party has the freedom to decide how any tiebreaks will be settled. Get creative and have fun!"
        case .cardsOfChaos:
            return "On each hole, cards will be drawn for your party that contain amusing rules for how your party and/or player can or cannot play the hole.\n\nCards can be favorable and generous making it easier to score (shown with a halo), or they can be challenging and make it more difficult to score as usual (shown with horns).\n\nYour party can decide to modify the rules for how cards are drawn, choosing to pick either a party card, player card(s), or get both. If drawing both with conflicting rules, the player card ruling will always take priority. Your party can choose different moods based on your generosity level, which will influence the algorithm for how common challenging cards are drawn."
        case .fibonacci:
            return "Teams or players will play each hole like stroke play and earn points based on their strokes. The scoring format follows the Fibonacci sequence which simply says that a number is the sum of the two numbers before it. The highest score at the end of the game is the winner."
        case .football:
            return "Players will play each hole using the best ball format. Whoever has the furthest drive on the first tee will start on offense. The offense will try to win the hole for a touchdown (7pt) or tie the hole for a field goal (3 pts). The defense can stop the offense with a turnover on downs by winning the hole, and should the defense win with a birdie or better, they score a pick six (6 pts).\n\n**Possession & Turnovers**\nPossession changes after each hole, but turnovers can also occur during the hole that gives the defense possession immediately:\n\n*Fumble!* If any offensive player lands in a bunker, they must hit the green on their next shot or lose possession.\n\n*Interception!* If any offensive player loses a ball out of bounds, to a hazard, or to water and requires a drop, they lose possesssion.\n\nPossession changes occur immediately and multiple turnovers can happen on the hole, as long as they occur sequentially.\n\n**Onside Kicks**\nIf the offense scored on the prior hole, they can elect to onside kick on the next tee. All offense players will tee first and must each hit the fairway, or green on par 3s. If they succeed, they keep possession. However, if they fail, the defense gets possession and a safety (2 pts)."
        case .hammer:
            return "Yet to be written"
        case .hotPotato:
            return "On each hole, the hot potato is ready to jump into the leaping arms of one of your party members and passed around depending on outcomes on the hole. The goal is to simply not be holding the hot potato when everyone finishes the hole. You possess the hot potato by doing one of the following:\n\n1.  Miss the fairway (green on Par 3)\n2. Land in a bunker\n3. Lose a ball that requires drop\n4. Three putt\n\nThe potato is passed chronologically as events happen - i.e. if two players miss the fairway or three putt, the potato belongs to whoever did it most recently.\n\nWhichever player or team is holding the hot potato when the hole ends with have their score doubled! The potato then resets on the next hole. "
        case .medalPlay:
            return "Players will play their own ball for the entirely of each hole. The sum of strokes on each hole will be the player's score with the lowest score being the winner overall. Refer to the [USGA Rules](https://www.usga.org/rules/rules-and-clarifications/rules-and-clarifications.html#!ruletype=fr&section=rule&rulenum=1) if you're curious."
        case .monkeyInTheMiddle:
            return "The player whose shot off the tee is the middle distance away from the pin is the monkey. The other two players (with the closest and furthest tee shots from the pin) will team up against the monkey 2v1 in stroke play, with the monkey's score being doubled. If the monkey wins, they get 2 points. Otherwise, the rest of the group gets 1 point each."
        case .nines:
            return "Every hole gives four different scenarios for players to earn 9 points depending on scoring outcomes:"
        case .stableford:
            return "Teams or players will play each hole like stroke play and earn points based on their strokes. The scoring format follows the Stableford system which only rewards points when players bogey or better. The highest score at the end of the game is the winner."
        case .survivor:
            return "Every player will be choose number of lives to start the game! As the game progresses, players will gain 1 life for every shot under par, but lose 1 life for every stroke over par. Slowly, lives in your party will chip away until there's only one player standing victorious!\n\nThis game can be played with or with handicaps depending on how your party wants to organize the game."
        case .vegas:
            return "Each player on the team will play their own ball. When the hole is complete, the Vegas score will be computed by multiplying the lowest score by 10 and then adding it to the highest score. Examples:\n\nTeam A shoots a bogey (+1) and double (+2). Since a bogey is best, this score is 10x so\n(1 x 10) + 2 = 12.\n\nTeam B shoots a birdie (-1) and triple (+3). Since a birdie is best, this score is 10x so\n(-1 x 10) + 3 = -7.\n\nTeam C shoots an eagle (-2) and birdie (-1). Since an eagle is best, this score is 10x so\n(-2 x 10) + (-1) = -21.\n\nThe important trend here is your team can remain competitive as long as one player scores well compared to the group.\n\nOn each hole, the team with the lowest combined score wins the hole and earns points equals to their margin of victory.  At the end of the game, the team with the most points wins."
        case .wolfHammer:
            return "On each hole, players will be competing either as 2v2 or 1v3 for points known as *dots*. These dots can be earned by team play, as well as side outcomes called *The Junk*. If playing for high stakes, the party should decide on a value worth for each dot. We highly recommend keeping it small to start.\n\nOn each hole, one player is designated as *The Wolf*. The wolf will start with the first player and then rotate through to the next player, keeping the same order throughout for the entirely of the game.\n\nOn the tee, the Wolf has three options:\n\n1. Tee last and pick a partner for 2v2 in a match worth 2 dots.\n2. Tee last and go lone wolf 1v3 in a match worth 6 dots.\n3. Tee first and go blind lone wolf 1v3 in a match worth 12 dots.\n\nThe player with the best ball for their team will win dots for everyone on their team. Dots will be evenly distributed.\n\n**Hammers**\nIf one team is feeling confident, they can make the first move to *throw the hammer* to the opposing team. Like pressing, this proposes doubling the bet for the hole. When the hammer is thrown at your team, you can:\n\n1. *Take* the hammer and accept doubling the bet. Your team would have the hammer to throw back at any time.\n2. *Reject* the hammer, giving the throwing team 1 dot each and ending future hammers on the hole.\n3. *Boomerang* the hammer, taking it and immediately throwing it back to quadruple the bet (if taken).\n\nEach team can only throw the hammer once. The hammer is only eligible for being thrown while each team has one player still playing. The highest possible dots per hole would be 48 (blind lone wolf wins with boomerang).\n\n**The Junk**\nTo elevate the competition even further, the team can decide to optionally add junk into the mix. Junk items are specific scenarios that happen on a course that reward a preset number of dots to any player that meets the junk criteria on the hole. Junk dots are added to player totals in addition to team play and are not influenced by any actions that occur in team play.\n\nAt the end of the game, the player(s) with lower dot values can expect to be responsible for holding true to the original terms of the game and squaring up with player who came out looking quite nice. Good luck and play responsibly!"
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
                row(title: "T-1st", value: "3")
                row(title: "T-1st", value: "3")
                row(title: "T-1st", value: "3")
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
        VStack { }.sheet(isPresented: .true) {
            SideGameHowToView(game: .football)
                .presentationDragIndicator(.visible)
        }
        .holisticPreview()
    }
}
