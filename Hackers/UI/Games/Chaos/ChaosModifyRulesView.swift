//
//  ChaosModifyRulesView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/23.
//

import SwiftUI

struct ChaosModifyRulesView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    
    @State private var arrangement: ChaosCardsArrangement = .player
    @State private var difficulty: ChaosCardsDifficulty = .medium
    @State private var redraws: Bool = false
    
    @State private var originalArrangement: ChaosCardsArrangement = .player
    
    private var forceRedraw: Bool {
        self.originalArrangement != self.arrangement
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                content
                
                Spacer(minLength: 0)

                if !forceRedraw {
                    SmallButton(
                        title: "Save & redraw cards",
                        isDisabled: .false,
                        isLoading: .false
                    )
                    .onTapAsync {
                        save()
                        await viewModel.draw(for: roundSession.players, on: hole)
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                }
                
                BigButton(
                    title: "Save & \(forceRedraw ? "redraw" : "keep") cards",
                    buttonColor: .systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTapAsync {
                    save()
                    if forceRedraw {
                        await viewModel.draw(for: roundSession.players, on: hole)
                        dismiss()
                    } else {
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 10)
            .navigationTitle("Cards of Chaos")
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
        .onAppear() { load(viewModel.sideGameSession) }
    }
    
    // MARK: - Data functions
    
    private func load(_ s: SideGameSession) {
        if let a = ChaosCardsArrangement(rawValue: s.chaos?.arrangement ?? "") {
            self.arrangement = a
            self.originalArrangement = a
        }
        
        if let d = ChaosCardsDifficulty(rawValue: s.chaos?.difficulty ?? "") {
            self.difficulty = d
        }
        
        self.redraws = s.chaos?.redraws ?? true
    }
    
    private func save() {
        viewModel.sideGameSession.chaos?.arrangement = self.arrangement.rawValue
        viewModel.sideGameSession.chaos?.difficulty = self.difficulty.rawValue
        viewModel.sideGameSession.chaos?.redraws = self.redraws
    }
    
    // MARK: - Content
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 40) {
                arrangementView
                difficultyView
                redrawView
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Arrangement
    
    private var arrangementView: some View {
        VStack(spacing: 20) {
            Group {
                Text("What ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("card type")
                    .foregroundColor(Color.systemHackersPurple)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" do you want?")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            
            PillDivider()
            
            HStack(spacing: 10) {
                arrangementButton(for: .team)
                arrangementButton(for: .player)
                arrangementButton(for: .combo)
            }
        }
    }
    
    @ViewBuilder private func arrangementButton(for a: ChaosCardsArrangement) -> some View {
        Button(action: {
            arrangement = a
            Haptics.fire(.light)
        }) {
            buttonLabel(for: a.label, isSelected: arrangement == a)
        }
    }
    
    // MARK: - Difficulty
    
    private var difficultyView: some View {
        VStack(spacing: 20) {
            Group {
                Text("What ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("attitude")
                    .foregroundColor(Color.systemHackersPurple)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" are you feeling?")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            
            PillDivider()
            
            HStack(spacing: 10) {
                difficultyButton(for: .easy)
                difficultyButton(for: .medium)
                difficultyButton(for: .hard)
            }
        }
    }
    
    @ViewBuilder private func difficultyButton(for d: ChaosCardsDifficulty) -> some View {
        Button(action: {
            difficulty = d
            Haptics.fire(.light)
        }) {
            buttonLabel(for: d.label, isSelected: difficulty == d)
        }
    }
    
    // MARK: - Redraws
    
    private var redrawView: some View {
        VStack(spacing: 20) {
            Group {
                Text("Do you want to play with ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("redraws")
                    .foregroundColor(Color.systemHackersPurple)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text("?")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            
            PillDivider()
            
            HStack(spacing: 10) {
                redrawButton(for: false)
                redrawButton(for: true)
            }
        }
    }
    
    @ViewBuilder private func redrawButton(for value: Bool) -> some View {
        Button(action: {
            redraws = value
            Haptics.fire(.light)
        }) {
            buttonLabel(for: value ? "Yes" : "No", isSelected: redraws == value)
        }
    }
    
    // MARK: - Components
    
    private func buttonLabel(for label: String, isSelected: Bool) -> some View {
        Text(label)
            .font(.dmSans(size: 17, weight: isSelected ? .bold : .medium))
            .foregroundColor(isSelected ? Color.systemHackersPurple : Color.systemBlack)
            .alignCenter()
            .padding(.vertical, 12)
            .background(isSelected ? Color.systemHackersPurple.opacity(colorScheme.translucent) : Color.systemCard)
            .border(
                isSelected ? Color.systemHackersPurple : colorScheme.lightGray,
                width: isSelected ? 6 : 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
    }
}

struct ChaosModifyRulesView_Previews: PreviewProvider {
    static var previews: some View {
        VStack { }.sheet(isPresented: .true) {
            ChaosModifyRulesView(viewModel: HoleViewModel(), hole: 4)
                .environmentObject(RoundSession())
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
        .holisticPreview()
    }
}
