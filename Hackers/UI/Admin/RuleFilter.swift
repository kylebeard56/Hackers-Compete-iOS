//
//  RuleFilter.swift
//  Hackers
//
//  Created by Kyle Beard on 11/18/22.
//

import SwiftUI

struct RuleFilterData {
    var pack: PackName
    var type: RuleType
    var difficulty: RuleDifficulty
}

struct RuleFilter: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var pack: PackName
    @Binding var type: RuleType
    @Binding var difficulty: RuleDifficulty
    
    var onApply: OnSelection
    var onClear: OnSelection
    
    var body: some View {
        ZStack {
            ScrollView {
                content
            }
            
            HStack(spacing: 16) {
                BigButton(
                    style: .outline,
                    title: "Clear",
                    labelColor: Color.systemBlack,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: clearTapped
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                
                BigButton(
                    style: .solid,
                    title: "Apply",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: applyTapped
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .alignBottom()
            .ignoresSafeArea(.keyboard)
        }
        .padding(16)
        .background(Color.systemViewBackground)
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ZStack {
                        BackButton(icon: .xmark, onTap: { dismiss() })
                            .alignLeading()
                        
                        Text("Filter")
                            .font(.dmSans(size: 17, weight: .bold))
                    }
                    .padding(.top, 16)
                    
                    HStack(spacing: 16) {
                        Text("Pack:")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                            .frame(width: 60)
                        selectionButton(
                            label: "Gameplay",
                            isSelected: pack == .gameplay,
                            onTap: { pack = .gameplay })
                        selectionButton(
                            label: "Drinking",
                            isSelected: pack == .drinking,
                            onTap: { pack = .drinking })
                    }
                    .padding(.top, 16)
                    
                    if pack == .gameplay {
                        HStack(spacing: 16) {
                            Text("Type:")
                                .font(.dmSans(size: 17, weight: .medium))
                                .foregroundColor(Color.systemBlack)
                                .alignLeading()
                                .frame(width: 60)
                            selectionButton(
                                label: "Team",
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
                        
                        HStack(spacing: 16) {
                            Text("Level:")
                                .font(.dmSans(size: 17, weight: .medium))
                                .foregroundColor(Color.systemBlack)
                                .alignLeading()
                                .frame(width: 60)
                            selectionButton(
                                label: "Easy",
                                isSelected: difficulty == .favor,
                                onTap: { difficulty = .favor })
                            selectionButton(
                                label: "Hard",
                                isSelected: difficulty == .challenge,
                                onTap: { difficulty = .challenge })
                            selectionButton(
                                label: "Both",
                                isSelected: difficulty == .both,
                                onTap: { difficulty = .both })
                        }
                    }
                    
                    if pack == .drinking {
                        HStack(spacing: 16) {
                            Text("Type:")
                                .font(.dmSans(size: 17, weight: .medium))
                                .foregroundColor(Color.systemBlack)
                                .alignLeading()
                                .frame(width: 60)
                            selectionButton(
                                label: "Round",
                                isSelected: type == .round,
                                onTap: { type = .round })
                            selectionButton(
                                label: "Hole",
                                isSelected: type == .hole,
                                onTap: { type = .hole })
                        }
                        
                        HStack(spacing: 16) {
                            Text("Level:")
                                .font(.dmSans(size: 17, weight: .medium))
                                .foregroundColor(Color.systemBlack)
                                .alignLeading()
                                .frame(width: 60)
                            selectionButton(
                                label: "Give",
                                isSelected: difficulty == .give,
                                onTap: { difficulty = .give })
                            selectionButton(
                                label: "Take",
                                isSelected: difficulty == .take,
                                onTap: { difficulty = .take })
                        }
                    }
                }
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
    
    private func clearTapped() {
        if let action = onClear {
            Haptics.fire(.light)
            action()
            dismiss()
        }
    }
}

struct RuleFilter_Previews: PreviewProvider {
    static var previews: some View {
        RuleFilter(
            pack: .constant(.gameplay),
            type: .constant(.both),
            difficulty: .constant(.favor),
            onApply: {},
            onClear: {})
    }
}
