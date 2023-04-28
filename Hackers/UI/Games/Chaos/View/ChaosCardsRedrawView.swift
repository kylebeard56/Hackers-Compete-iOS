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
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Redraw count")
                    .font(.dmSans(size: 28, weight: .bold))
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
                stepper(text: "Team", value: 3, onIncrement: { }, onDecrement: { })
                stepper(text: "Player 1", value: 3, onIncrement: { }, onDecrement: { })
                stepper(text: "Player 2", value: 3, onIncrement: { }, onDecrement: { })
                stepper(text: "Player 3", value: 3, onIncrement: { }, onDecrement: { })
                stepper(text: "Player 4", value: 3, onIncrement: { }, onDecrement: { })
            }
            .padding(16)
            .border(Color.systemGray6, width: 2, cornerRadius: 8)
            
            Spacer(minLength: 0)
            
            HStack(spacing: 12) {
                Button(action: {
                    Haptics.fire(.light)
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
                Haptics.fire(.light)
            }) {
                Text("-")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
            }
            
            Text("\(value)")
                .font(.dmSans(size: 17, weight: .bold))
                .foregroundColor(Color.systemHackersGreen)
                .padding(.horizontal, 24)
                .frame(height: 44)
                .background(Color.systemHackersGreen.opacity(0.125))
                .cornerRadius(8)
            
            Button(action: {
                onDecrement()
                Haptics.fire(.light)
            }) {
                Text("+")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Color.systemGray6)
                    .cornerRadius(8)
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
