//
//  ChaosRuleFilter.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/23.
//

import SwiftUI

struct ChaosRuleFilter: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var type: RuleType
    @Binding var difficulty: RuleDifficulty
    
    var onApply: OnSelection
    
    var body: some View {
        NavigationStack {
            content
                .padding(.vertical, 10)
                .navigationTitle("Filter cards")
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
        .background(Color.systemViewBackground)
        .padding(.horizontal, 20)
    }
    
    private var content: some View {
        VStack(spacing: 20) {
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
                
                HStack(spacing: 20) {
                    selectionButton(
                        label: "Party",
                        isSelected: type == .team,
                        onTap: { type = .team })
                    selectionButton(
                        label: "Player",
                        isSelected: type == .player,
                        onTap: { type = .player })
                    selectionButton(
                        label: "Both",
                        isSelected: type == .both,
                        onTap: { type = .both })
                }
            }
            
            VStack(spacing: 20) {
                Group {
                    Text("What ")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 17, weight: .regular))
                    + Text("difficulty")
                        .foregroundColor(Color.systemHackersPurple)
                        .font(.dmSans(size: 17, weight: .bold))
                    + Text(" do you want?")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 17, weight: .regular))
                }
                
                PillDivider()
                
                HStack(spacing: 20) {
                    selectionButton(
                        label: "Favor",
                        isSelected: difficulty == .favor,
                        onTap: { difficulty = .favor })
                    selectionButton(
                        label: "Challenge",
                        isSelected: difficulty == .challenge,
                        onTap: { difficulty = .challenge })
                    selectionButton(
                        label: "Both",
                        isSelected: difficulty == .both,
                        onTap: { difficulty = .both })
                }
            }
            
            Spacer(minLength: 0)
                
            BigButton(
                title: "Apply",
                buttonColor: Color.systemHackersPurple,
                isDisabled: .false,
                isLoading: .false
            )
            .onTap {
                applyTapped()
            }
        }
    }
    
    private func selectionButton(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.fire(.light)
            onTap()
        }) {
            VStack {
                Text(label)
                    .frame(height: 40)
                    .font(.dmSans(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? Color.systemBlack : Color.systemGray2)
                    .alignCenter()
                    .background(Color.clear)
                    .border(
                        isSelected ? Color.systemBlack : Color.systemGray4, width: isSelected ? 4 : 2, cornerRadius: 10
                    )
                    .cornerRadius(10)
            }
        }
    }
    
    private func applyTapped() {
        if let action = onApply {
            Haptics.fire(.light)
            action()
            dismiss()
        }
    }
}
