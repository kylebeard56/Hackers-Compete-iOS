//
//  HoleSelectionView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct HoleSelectionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession

    var isFinalHole: Bool = false
    
    @State private var tab: Int = 0
    
    private var width: CGFloat {
        (UIScreen.main.bounds.width - 80) / 3
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
            return roundSession.holeRange[i + 1]
        } else {
            return -999
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Holes")
                    .font(.dmSans, size: 28, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.horizontal, 20)

            Group {
                Text("Your party has ")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
                + Text("**\(holesLeft) holes**")
                    .foregroundColor(Color.systemHackersGreen)
                    //.font(.dmSans, size: 17, weight: .bold)
                + Text(" left to play.")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
            }
            .font(.dmSans, size: 17)
            .multilineTextAlignment(.leading)
            .alignLeading()
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            if roundSession.numberOfHoles == 18 {
                TabView(selection: $tab) {
                    frontNine
                        .tag(0)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    backNine
                        .tag(1)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: UIScreen.main.bounds.width + 20)
                /// ^ since the grid is 3x3 we can assume square therefore width == height
            } else {
                if roundSession.startingHole > 9 {
                    backNine
                        .padding(.horizontal, 20)
                } else {
                    frontNine
                        .padding(.horizontal, 20)
                }
            }
            
            Spacer(minLength: 0)
            
            if isUnscoredHole {
                VStack(spacing: 20) {
                    Text("Heads up! You didn't add any scores for Hole \(roundSession.currentHole).")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans, size: 13, weight: .medium)
                        .alignCenter()
                        .padding(.horizontal, 20)

                    if isFinalHole {
                        finishRoundButton
                    } else {
                        nextHoleButton
                    }
                }
                .padding(.vertical, 20)
                .background(Color.systemHackersGreen.opacity(colorScheme.translucent))//colorScheme.superlightGray)
                .cornerRadius(20)
                .padding(.horizontal, 20)
            } else {
                if isFinalHole {
                    finishRoundButton
                } else {
                    nextHoleButton
                }
            }
        }
        .environmentObject(roundSession)
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .onAppear() {
            tab = roundSession.currentHole > 9 ? 1 : 0
            UIPageControl.appearance().pageIndicatorTintColor = colorScheme.pageIndicatorTintColor
            UIPageControl.appearance().currentPageIndicatorTintColor = colorScheme.currentPageIndicatorTintColor
        }
    }
    
    private var finishRoundButton: some View {
        BigButton(
            title: "Finish round" + unscoredSuffix,
            isDisabled: .false,
            isLoading: .false
        )
        .onTapAsync { await appSession.leaveRound() }
        .padding(.horizontal, 20)
    }
    
    private var nextHoleButton: some View {
        BigButton(
            title: "Go to Hole \(nextHoleNumber)" + unscoredSuffix,
            isDisabled: .false,
            isLoading: .false
        )
        .onTap {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                roundSession.currentHole = nextHoleNumber
            })
        }
        .padding(.horizontal, 20)
    }
    
    private var frontNine: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                button(for: 1)
                button(for: 2)
                button(for: 3)
            }
            HStack(spacing: 20) {
                button(for: 4)
                button(for: 5)
                button(for: 6)
            }
            HStack(spacing: 20) {
                button(for: 7)
                button(for: 8)
                button(for: 9)
            }
            Spacer(minLength: 0)
        }
    }
    
    private var backNine: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                button(for: 10)
                button(for: 11)
                button(for: 12)
            }
            HStack(spacing: 20) {
                button(for: 13)
                button(for: 14)
                button(for: 15)
            }
            HStack(spacing: 20) {
                button(for: 16)
                button(for: 17)
                button(for: 18)
            }
            Spacer(minLength: 0)
        }
    }
    
    @ViewBuilder private func button(for hole: Int) -> some View {
        let isCurrent = roundSession.currentHole == hole
        let isScored = roundSession.scoringExists(for: hole)
        let foregroundColor = isCurrent ? Color.systemWhite : isScored ? Color.systemHackersGreen : Color.systemGray3
        let game = game(for: hole)
        
        Button(action: {
            roundSession.currentHole = hole
            Haptics.fire(.light)
            dismiss()
        }) {
            ZStack {
                if hole == roundSession.startingHole {
                    Circle()
                        .fill(foregroundColor)
                        .frame(width: 6, height: 6)
                        .alignLeading()
                        .alignTop()
                }
                
                if game != .none {
                    AwesomeImage(rawIcon: game.icon.unicode, style: .solid, size: 12, color: foregroundColor)
                        .alignTrailing()
                        .alignTop()
                }
                
                Text("\(hole)")
                    .font(.dmSans, size: 28, weight: .bold)
                    .foregroundColor(foregroundColor)
            }
            .padding(12)
            .frame(width: width, height: width)
            .background(
                isCurrent
                ? Color.systemHackersGreen
                : isScored
                ? Color.systemHackersGreen.opacity(colorScheme.translucent)
                : Color.systemGray6
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: strokeStyle)
                    .foregroundColor(isCurrent || isScored ? Color.clear : Color.systemGray3)
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
    static var appSession = AppSession()
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
