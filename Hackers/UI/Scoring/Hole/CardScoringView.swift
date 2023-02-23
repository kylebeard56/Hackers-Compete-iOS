//
//  CardScoringView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/17/23.
//

import SwiftUI

struct CardScoringView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var onNextHole: OnSelection?
    var onClose: OnSelection?
    
    private let kDiameter: CGFloat = 150
    private let ruleTypeOffset: CGFloat = 32
    
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            ZStack(alignment: .top) {
                cardBody
                iconCircle
                    .padding(.top, ruleTypeOffset)
            }
            .padding(kPadding)
        }
    }
    
    // MARK: - Components
    
    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(Color.systemCard)
                .frame(width: kDiameter, height: kDiameter)
            Circle()
                .stroke(Color.systemGray3, lineWidth: 5)
                .frame(width: kDiameter, height: kDiameter)
            
            AwesomeImage(
                rawIcon: "f303".unicode,
                style: .regular,
                size: 72,
                color: Color.systemBlack)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 0)
    }
    
    private var cardBody: some View {
        VStack {
            Spacer()
                .frame(height: kDiameter * 0.6 + ruleTypeOffset)
            
            VStack(spacing: 24) {
                Button(action: closeTapped) {
                    AwesomeImage(icon: .xmark, style: .solid, size: 24, color: .systemGray3)
                        .alignMiddle()
                        .alignTrailing()
                        .padding(.trailing, 4)
                }
                .frame(height: 40)
                
                VStack(spacing: 8) {
                    Text(viewModel.currentHole == 18 ? "Ready to see your round summary?" : "Ready for the next hole?")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(colorScheme == .light ? .systemGray3 : .systemGray)
                    
                    Text("Scorecard")
                        .font(.dmSans(size: 40, weight: .bold))
                        .foregroundStyle(Color.systemBlack)
                        .multilineTextAlignment(.center)
                        .alignCenter()
                }
                
                PillDivider()
                    .padding(.top, -8)
                
                ScrollView {
                    Text("Thru \(viewModel.currentHole)")
                        .font(.dmSans(size: 12, weight: .bold))
                        .foregroundStyle(Color.systemGray3)
                        .frame(width: 56)
                        .alignTrailing()
                    
                    Divider()
                    
                    ForEach($viewModel.players, id: \.self) { player in
                        ScoringRow(player: player, currentHole: viewModel.currentHole)
                            .padding(.horizontal, 8)
                        Divider()
                    }
                }
                .padding(.horizontal, -kPadding)
                
                Spacer(minLength: 0)
                
                BigButton(
                    style: .solid,
                    title: viewModel.currentHole == 18 ? "Go to round summary" : "Go to next hole",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    height: 50,
                    radius: 16,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: nextHoleTapped)
                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 4)
                .padding(.bottom, kPadding)
            }
            .alignCenter()
            .padding(kPadding)
            .background(Color.systemCard)
            .cornerRadius(50)
            .border(Color.systemGray2, width: 1, cornerRadius: 50)
        }
    }
    
    // MARK: - Button Actions
    
    private func nextHoleTapped() {
        print(#function)
        if let action = onNextHole {
            action!()
        }
    }
    
    private func closeTapped() {
        print(#function)
        Haptics.fire(.light)
        if let action = onClose {
            action!()
        }
    }
}

struct CardScoringView_Previews: PreviewProvider {
    static var view: some View {
        CardScoringView(viewModel: RoundViewModel())
            .environmentObject(AppSession())
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
