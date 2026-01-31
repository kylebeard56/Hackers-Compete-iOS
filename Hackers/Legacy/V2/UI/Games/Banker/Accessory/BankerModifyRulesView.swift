//
//  BankerModifyRulesView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/22/24.
//

import SwiftUI

struct BankerModifyRulesView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSessionV2
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    @State private var maxWager: CGFloat = 100
    @State private var normalMultiplier: Int = 2
    @State private var parThreeMultiplier: Int = 3
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                content
                
                Spacer(minLength: 0)
                
                // TODO: If multipliers changed, it'll impact prior holes.
                
                BigButton(
                    title: "Set rules",
                    buttonColor: .systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTap {
                    viewModel.sideGameSession.banker?.maxWager = Int(maxWager)
                    viewModel.sideGameSession.banker?.normalMultiplier = normalMultiplier
                    viewModel.sideGameSession.banker?.parThreeMultiplier = parThreeMultiplier
                    dismiss()
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 10)
            .navigationTitle("Banker")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
        }
        .environmentObject(roundSession)
        .padding(.top, 10)
        .background(Color.systemViewBackground)
        .onAppear() {
            load(viewModel.sideGameSession)
        }
        .onChange(of: viewModel.sideGameSession, perform: { session in
            if let wager = session.banker?.maxWager {
                self.maxWager = CGFloat(wager)
            }
            if let normal = session.banker?.normalMultiplier {
                self.normalMultiplier = normal
            }
            if let par = session.banker?.parThreeMultiplier {
                self.parThreeMultiplier = par
            }
        })
    }
    
    private func load(_ session: SideGameSession) {
        guard let b = session.banker else { return }
        if let mw = b.maxWager {
            self.maxWager = CGFloat(mw)
        }
        if let nm = b.normalMultiplier {
            self.normalMultiplier = nm
        }
        if let ptm = b.parThreeMultiplier {
            self.parThreeMultiplier = ptm
        }
    }
    
    private var content: some View {
        VStack(spacing: 10) {
            slider
            stepper
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder private var slider: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(spacing: 4) {
                    Text("Wagers")
                        .font(.dmSans, size: 15, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Set the max player wager for each hole.")
                        .font(.dmSans, size: 13, weight: .medium)
                        .foregroundColor(Color.systemGray)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                }
                
                Spacer(minLength: 0)
                
                Text("\(Int(maxWager))")
                    .font(.dmSans, size: 20, weight: .bold)
                    .foregroundColor(Color.systemHackersPurple)
                    .frame(width: 48, height: 40)
                    .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                    .cornerRadius(8)
            }
            
            Slider(
                value: $maxWager,
                in: 50...300,
                step: 10
            ) {
                Text("Max Wager")
            } minimumValueLabel: {
                Text("50").font(.dmSans, size: 13, weight: .bold)
            } maximumValueLabel: {
                Text("300").font(.dmSans, size: 13, weight: .bold)
            }
            .tint(Color.systemHackersPurple)
            .onChange(of: maxWager, perform: { _ in Haptics.fire(.light) })
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
    
    @ViewBuilder private var stepper: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Multipliers")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Text("Set the press multiplers for players and the Banker.")
                    .font(.dmSans, size: 13, weight: .medium)
                    .foregroundColor(Color.systemGray)
                    .minimumScaleFactor(0.85)
                    .alignLeading()
            }
            
            HStack(spacing: 10) {
                Text("Normal")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text("\(normalMultiplier)")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemHackersPurple)
                    .frame(width: 40, height: 32)
                    .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                    .cornerRadius(8)
                
                Stepper(
                    "",
                    value: $normalMultiplier,
                    in: 2...10,
                    onEditingChanged: { _ in Haptics.fire(.light) }
                )
                .frame(width: 100)
            }
            
            HStack(spacing: 10) {
                Text("Par 3")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Text("\(parThreeMultiplier)")
                    .font(.dmSans, size: 15, weight: .bold)
                    .foregroundColor(Color.systemHackersPurple)
                    .frame(width: 40, height: 32)
                    .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                    .cornerRadius(8)
                
                Stepper(
                    "",
                    value: $parThreeMultiplier,
                    in: 2...10,
                    onEditingChanged: { _ in Haptics.fire(.light) }
                )
                .frame(width: 100)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
}

struct BankerModifyRulesView_Previews: PreviewProvider {
    static var app = AppSessionV2()
    static var round = RoundSession()
    static var viewModel = HoleViewModel()
    
    static var previews: some View {
        BankerModifyRulesView(viewModel: viewModel)
            .environmentObject(app)
            .environmentObject(round)
            .holisticPreview()
    }
}
