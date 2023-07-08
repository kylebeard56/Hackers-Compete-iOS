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
    @StateObject var viewModel: RoundViewModel

    @State private var tab: Int = 0
    
    private var width: CGFloat {
        (UIScreen.main.bounds.width - 80) / 3
    }
    
    private var holeLabel: String {
        appSession.numberOfHoles == 18 ? "18 holes" : "the \(appSession.startingHole > 9 ? "back" : "front") nine"
    }
    
    private var startingLabel: String {
        "\(viewModel.startingHole)\(viewModel.startingHole.numericalSuffix) hole"
    }
    
    private var holesLeft: Int {
        viewModel.numberOfHoles - (viewModel.players.map(\.scoreCount).max() ?? 0)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Holes")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.horizontal, 20)
            
//            Group {
//                Text("Your party is playing ")
//                    .foregroundColor(Color.systemBlack)
//                    .font(.dmSans(size: 17, weight: .regular))
//                + Text(holeLabel)
//                    .foregroundColor(Color.systemHackersGreen)
//                    .font(.dmSans(size: 17, weight: .bold))
//                + Text(" and started on the ")
//                    .foregroundColor(Color.systemBlack)
//                    .font(.dmSans(size: 17, weight: .regular))
//                + Text(startingLabel)
//                    .foregroundColor(Color.systemHackersGreen)
//                    .font(.dmSans(size: 17, weight: .bold))
//                + Text(" with \(holesLeft) holes left to play.")
//                    .foregroundColor(Color.systemBlack)
//                    .font(.dmSans(size: 17, weight: .regular))
//            }
            Group {
                Text("Your party has ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("\(holesLeft) holes")
                    .foregroundColor(Color.systemHackersGreen)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" left to play.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .multilineTextAlignment(.leading)
            .alignLeading()
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            if appSession.numberOfHoles == 18 {
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
            } else {
                if appSession.startingHole > 9 {
                    backNine
                        .padding(.horizontal, 20)
                } else {
                    frontNine
                        .padding(.horizontal, 20)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .onAppear() {
            tab = appSession.startingHole > 9 ? 1 : 0
            UIPageControl.appearance().pageIndicatorTintColor = colorScheme.pageIndicatorTintColor
            UIPageControl.appearance().currentPageIndicatorTintColor = colorScheme.currentPageIndicatorTintColor
        }
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
        let isCurrent = viewModel.currentHole == hole
        let isScored = !viewModel.players.compactMap({ $0.score[hole] }).isEmpty
        let foregroundColor = isCurrent ? Color.systemWhite : isScored ? Color.systemHackersGreen : Color.systemGray3
        
        Button(action: {
            viewModel.currentHole = hole
            Haptics.fire(.light)
            dismiss()
        }) {
            ZStack {
                if hole == appSession.startingHole {
                    AwesomeImage(rawIcon: "f11e".unicode, style: .solid, size: 15, color: foregroundColor)
                        .alignLeading()
                        .alignTop()
                }
                Text("\(hole)")
                    .font(.dmSans(size: 28, weight: .bold))
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
    static var viewModel = RoundViewModel()
    
    static var previews: some View {
        HoleSelectionView(viewModel: viewModel)
            .environmentObject(appSession)
            .onAppear() {
                viewModel.currentHole = 2
                appSession.startingHole = 1
                viewModel.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                viewModel.players[0].score.updateValue(PlayerScore.par.rawValue, forKey: 1)
            }
            .holisticPreview()
    }
}
