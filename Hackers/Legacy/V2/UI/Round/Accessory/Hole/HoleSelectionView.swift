//
//  HoleSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct HoleSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
//    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSessionV2
    @EnvironmentObject var roundSession: RoundSession

    var isFinalHole: Bool {
        roundSession.holeRange.last == roundSession.currentHole
    }
    
    @State private var tab: Int = 0
    
    private var width: CGFloat {
        (UIScreen.main.bounds.width - 60) / 3
    }
    
    private var holeLabel: String {
        roundSession.numberOfHoles == 18 ? "18 holes" : "the \(roundSession.startingHole > 9 ? "back" : "front") nine"
    }
    
    private var startingLabel: String {
        "\(roundSession.startingHole)\(roundSession.startingHole.numericalSuffix) hole"
    }
    
    private var holesLeft: Int {
        roundSession.numberOfHoles - (roundSession.players.map(\.scoreCount).max() ?? 0)
    }
    
    private var isUnscoredHole: Bool {
        !roundSession.scoringExists(for: roundSession.currentHole)
    }
    
    private var unscoredSuffix: String {
        isUnscoredHole ? " anyways" : ""
    }
    
    private var nextHoleNumber: Int {
        if let i = roundSession.holeRange.firstIndex(where: { $0 == roundSession.currentHole }) {
            return roundSession.holeRange[safe: i + 1] ?? -999
        } else {
            return -999
        }
    }
    
    var body: some View {
        //ScrollView(showsIndicators: false) {
            content
        //}
        .environmentObject(roundSession)
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .onAppear() {
            tab = roundSession.currentHole > 9 ? 1 : 0
            UIPageControl.appearance().pageIndicatorTintColor = colorScheme.pageIndicatorTintColor
            UIPageControl.appearance().currentPageIndicatorTintColor = colorScheme.currentPageIndicatorTintColor
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            VStack(spacing: 0) {
                Text("Holes")
                    .font(.dmSans, size: 32, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                Group {
                    Text("Your party has ")
                        .foregroundColor(Color.systemGray)
                    + Text("**\(holesLeft) holes**")
                        .foregroundColor(Color.systemHackersGreen)
                    + Text(" left to play.")
                        .foregroundColor(Color.systemGray)
                }
                .font(.dmSans, size: 15, weight: .medium)
                .multilineTextAlignment(.leading)
                .alignLeading()
            }
            .padding(.horizontal, 20)
            
//            ZStack {
//                Text("Holes")
//                    .font(.dmSans, size: 32, weight: .bold)
//                    .foregroundColor(Color.systemBlack)
//                    .alignLeading()
//
////                BackButton( icon: .xmark, onTap: { dismiss() })
////                    .alignTrailing()
//            }
//            .padding(.horizontal, 20)

//            Group {
//                Text("Your party has ")
//                    .foregroundColor(Color.systemBlack)
//                    //.font(.dmSans, size: 17, weight: .regular)
//                + Text("**\(holesLeft) holes**")
//                    .foregroundColor(Color.systemHackersGreen)
//                    //.font(.dmSans, size: 17, weight: .bold)
//                + Text(" left to play.")
//                    .foregroundColor(Color.systemBlack)
//                    //.font(.dmSans, size: 17, weight: .regular)
//            }
//            .font(.dmSans, size: 17)
//            .multilineTextAlignment(.leading)
//            .alignLeading()
//            .padding(.horizontal, 20)
//            .padding(.bottom, 20)
            
            if roundSession.numberOfHoles == 18 {
                Picker("", selection: $tab) {
                    Text("Front").tag(0)
                    Text("Back").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                
                if tab == 0 {
                    frontNine
                }
                
                if tab == 1 {
                    backNine
                }
                
//                TabView(selection: $tab) {
//                    frontNine
//                        .tag(0)
//                        //.padding(.horizontal, 20)
//                        //.padding(.bottom, 10)
//                    backNine
//                        .tag(1)
//                        //.padding(.horizontal, 20)
//                        //.padding(.bottom, 10)
//                }
//                .tabViewStyle(.page(indexDisplayMode: .always))
//                .frame(height: UIScreen.main.bounds.width + 40)
                /// ^ since the grid is 3x3 we can assume square therefore width == height
            } else {
                if roundSession.startingHole > 9 {
                    backNine
//                        .padding(.horizontal, 20)
                } else {
                    frontNine
//                        .padding(.horizontal, 20)
                }
            }
            
            Spacer(minLength: 0)

            if isUnscoredHole {
                VStack(spacing: 20) {
                    Button(action: {
                        withAnimation {
                            roundSession.selectedTab = .leaderboard
                        }
                        Haptics.fire(.light)
                    }) {
                        Text("Heads up! You didn't add scores for Hole \(roundSession.currentHole).")
                            .foregroundColor(Color.systemError)
                            .font(.dmSans, size: 13, weight: .bold)
                            .alignCenter()
                            .padding(.horizontal, 20)
                    }

                    if isFinalHole {
                        finishRoundButton(.systemError)
                    } else {
                        nextHoleButton(.systemError)
                    }
                }
                .padding(.vertical, 20)
                .background(Color.systemError.opacity(colorScheme.translucent))
                .cornerRadius(20)
                .padding(.horizontal, 20)
            } else {
                if isFinalHole {
                    finishRoundButton()
                } else {
                    nextHoleButton()
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    private func finishRoundButton(_ color: Color = Color.systemHackersGreen) ->  some View {
        BigButton(
            title: "Finish round" + unscoredSuffix,
            labelColor: Color.white,
            buttonColor: color,
            isDisabled: .false,
            isLoading: .false
        )
        .onTapAsync { await appSession.leaveRound() }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder private func nextHoleButton(_ color: Color = Color.systemHackersGreen) -> some View {
        let text = if isUnscoredHole {
            "Go to next hole anyways (No. \(nextHoleNumber))"
        } else {
            "Go to next hole (No. \(nextHoleNumber))"
        }
        BigButton(
            title: text,
            labelColor: Color.white,
            buttonColor: color,
            isDisabled: .false,
            isLoading: .false
        )
        .onTap {
            //dismiss()
            roundSession.animateCurrentHole = nextHoleNumber
        }
        .padding(.horizontal, 20)
    }
    
    private var frontNine: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                button(for: 1)
                button(for: 2)
                button(for: 3)
            }
            HStack(spacing: 10) {
                button(for: 4)
                button(for: 5)
                button(for: 6)
            }
            HStack(spacing: 10) {
                button(for: 7)
                button(for: 8)
                button(for: 9)
            }
        }
    }
    
    private var backNine: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                button(for: 10)
                button(for: 11)
                button(for: 12)
            }
            HStack(spacing: 10) {
                button(for: 13)
                button(for: 14)
                button(for: 15)
            }
            HStack(spacing: 10) {
                button(for: 16)
                button(for: 17)
                button(for: 18)
            }
        }
    }
    
    @ViewBuilder private func button(for h: Int) -> some View {
        let hole = roundSession.holeRange[safe: h - 1] ?? h
        let isCurrent = roundSession.currentHole == hole
        let isScored = roundSession.scoringExists(for: hole)
        let isError = !isScored && hole < roundSession.currentHole
        let foregroundColor: Color = {
            if isCurrent { return Color.systemHackersGreen }
            if isError { return Color.systemError }
            if isScored { return Color.systemBlack }
            return Color.systemGray2
        }()
        let game = game(for: hole)
        
        Button(action: {
            roundSession.animateCurrentHole = hole
            Haptics.fire(.light)
        }) {
            ZStack {
                if hole != h {
                    Text("\(h)")
                        .font(.dmSans, size: 11, weight: .bold)
                        .foregroundColor(foregroundColor)
                        .alignLeading()
                        .alignTop()
                }
                
                if isError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(foregroundColor)
                        .alignTrailing()
                        .alignTop()
                } else if game != .none {
                    AwesomeImage(rawIcon: game.icon.unicode, style: .regular, size: 11, color: foregroundColor)
                        .alignTrailing()
                        .alignTop()
                }
                
                Text("\(hole)")
                    .font(.dmSans, size: 28, weight: .bold)
                    .foregroundColor(foregroundColor)
                    .alignMiddle()
            }
            .padding(12)
            .frame(width: width)
            .frame(maxHeight: width)
            .background(
                isCurrent
                ? Color.systemHackersGreen.opacity(colorScheme.translucent)
                : isError
                ? Color.systemError.opacity(colorScheme.translucent)
                : isScored
                ? colorScheme.superlightGray
                : Color.clear
            )
            .cornerRadius(10)
            .overlay(
                Group {
                    if isCurrent || isScored || isError {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCurrent ? Color.systemHackersGreen
                                : isError ? Color.systemError
                                : colorScheme.superlightGray,
                                lineWidth: 2
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(style: strokeStyle)
                            .foregroundStyle(Color.systemGray3)
                    }
                }
            )
        }
    }
    
    private func game(for hole: Int) -> SideGame {
        var game: SideGame = .none
        if let s = roundSession.sideGameSessions.first(where: { $0.holes.contains(hole) }), let g = SideGame(rawValue: s.game) {
            game = g
        }
        return game
    }
    
    private var strokeStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 0,
            dash: [4, 10],
            dashPhase: 0
        )
    }
}

struct HoleSelectionView_Previews: PreviewProvider {
    static var appSession = AppSessionV2()
    static var roundSession = RoundSession()
    
    static var previews: some View {
        HoleSelectionView()
            .environmentObject(appSession)
            .environmentObject(roundSession)
            .onAppear() {
                appSession.startingHole = 1
                roundSession.currentHole = 2
                roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                roundSession.players[0].score.updateValue(PlayerScore.par.rawValue, forKey: 1)
            }
            .holisticPreview()
    }
}
