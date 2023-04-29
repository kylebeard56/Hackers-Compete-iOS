//
//  ChaosCardsRedrawView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/28/23.
//

import SwiftUI

struct ChaosCardsRedrawView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: ChaosViewModel
    
    @State private var teamRedraws: Int = 0
    @State private var players: [Player] = []
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Redraw count")
                    .font(.fugazOne(size: 32))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }
            
            Text("Use redraws advantageously to help balance parties of varying skill level.")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            VStack(spacing: 16) {
                stepper(
                    text: "Team",
                    value: teamRedraws,
                    onIncrement: {
                        teamRedraws += 1
                        if teamRedraws > kInfiniteRedraws {
                            teamRedraws = kInfiniteRedraws
                        }
                    },
                    onDecrement: {
                        teamRedraws -= 1
                        if teamRedraws < 0 {
                            teamRedraws = kInfiniteRedraws
                        }
                    }
                )
                ForEach(players, id: \.self) { p in
                    stepper(
                        text: p.name,
                        value: p.redrawCount,
                        onIncrement: { increment(for: p.id) },
                        onDecrement: { decrement(for: p.id) }
                    )
                }
            }
            .padding(16)
            .border(Color.systemGray6, width: 2, cornerRadius: 8)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.resetRedraws()
                    Haptics.fire(.light)
                    self.players = viewModel.players
                }) {
                    Text("Reset")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
                Button(action: {
                    save()
                    Haptics.fire(.light)
                }) {
                    Text("Save")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemWhite)
                        .alignCenter()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.systemBlack)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.systemCard)
        .onAppear() {
            self.players = viewModel.players
            self.teamRedraws = viewModel.teamRedrawCount
        }
    }
    
    @ViewBuilder
    private func stepper(
        text: String,
        value: Int,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemBlack)
            
            Spacer(minLength: 0)
            
            Button(action: {
                onDecrement()
                FirebaseEvent.chaosRedrawsMixDecremented.log()
                Haptics.fire(.light)
            }) {
                Text("-")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .frame(width: 40, height: 40)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
            }
            
            Group {
                if value == kInfiniteRedraws {
                    Image(systemName: "infinity")
                } else {
                    Text("\(value)")
                }
            }
            .font(.dmSans(size: 17, weight: .bold))
            .foregroundColor(Color.systemHackersGreen)
            .frame(width: 60, height: 40)
            .background(Color.systemHackersGreen.opacity(0.125))
            .cornerRadius(8)
            
            Button(action: {
                onIncrement()
                FirebaseEvent.chaosRedrawsMixIncremented.log()
                Haptics.fire(.light)
            }) {
                Text("+")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .frame(width: 40, height: 40)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
            }
        }
    }
    
    private func save() {
        viewModel.players = self.players
        viewModel.teamRedrawCount = self.teamRedraws
        dismiss()
    }
    
    /// Increment and guard upper bound to infinite constant
    private func increment(for id: String) {
        if let i = players.firstIndex(where: { $0.id == id }) {
            players[i].redrawCount += 1
            if players[i].redrawCount > kInfiniteRedraws {
                players[i].redrawCount = 0
            }
        }
    }
    
    /// Decrement and guard lower bound to 0
    private func decrement(for id: String) {
        if let i = players.firstIndex(where: { $0.id == id }) {
            players[i].redrawCount -= 1
            if players[i].redrawCount < 0 {
                players[i].redrawCount = kInfiniteRedraws
            }
        }
    }
}

struct ChaosCardsRedrawView_Previews: PreviewProvider {
    static var view: some View {
        VStack {
            ChaosCardsRulesView(viewModel: RoundViewModel())
                .environmentObject(AppSession())
        }
        .sheet(isPresented: .true) {
            ChaosCardsRedrawView(viewModel: ChaosViewModel())
                .presentationDragIndicator(.visible)
                .presentationDetents([.height(540), .large])
        }
    }
    
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
