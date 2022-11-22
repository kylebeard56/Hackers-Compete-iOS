//
//  CustomizeGamePlayView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/9/22.
//

import SwiftUI

struct CustomizeGamePlayView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: GameplayViewModel
    
    @State private var teamDifficulty: RuleDifficulty = .easy
    @State private var playerDifficulty: RuleDifficulty = .easy
    
    var body: some View {
        NavigationStack {
            VStack(spacing: kPadding / 2) {
                Group {
                    Text("Team Rules")
                        .font(.dmSans(size: 32, weight: .bold))
                        .foregroundStyle(kGameplayPack.style.linearGradient)
                        .alignLeading()
                    
                    Text("One rule every player must follow for this hole.")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                        .padding(.top, -8)
                        .padding(.bottom, 8)
                    
                    Text("Choose difficulty:")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    HStack(spacing: kPadding) {
                        selectionButton(
                            label: "Easy",
                            isSelected: teamDifficulty == .easy,
                            onTap: { teamDifficulty = .easy }
                        )
                        selectionButton(
                            label: "Hard",
                            isSelected: teamDifficulty == .hard,
                            onTap: { teamDifficulty = .hard }
                        )
                        selectionButton(
                            label: "None",
                            isSelected: teamDifficulty == .none,
                            onTap: { teamDifficulty = .none }
                        )
                    }
                    
                    if teamDifficulty == .easy {
                        easyDetailChip(.team)
                            .padding(.top, 8)
                    }
                    
                    if teamDifficulty == .hard {
                        hardDetailChip(.team)
                            .padding(.top, 8)
                    }
                    
                    if teamDifficulty == .none {
                        skippedChip(.team)
                            .padding(.top, 8)
                    }
                }
                
                Group {
                    Text("Player Rules")
                        .font(.dmSans(size: 32, weight: .bold))
                        .foregroundStyle(kGameplayPack.style.linearGradient)
                        .alignLeading()
                        .padding(.top, kPadding)
                    
                    Text("A different rule for each player, weighted fairly.")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .alignLeading()
                        .padding(.top, -8)
                        .padding(.bottom, 8)
                    
                    Text("Choose difficulty:")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    HStack(spacing: kPadding) {
                        selectionButton(
                            label: "Easy",
                            isSelected: playerDifficulty == .easy,
                            onTap: { playerDifficulty = .easy }
                        )
                        selectionButton(
                            label: "Hard",
                            isSelected: playerDifficulty == .hard,
                            onTap: { playerDifficulty = .hard }
                        )
                        selectionButton(
                            label: "None",
                            isSelected: playerDifficulty == .none,
                            onTap: { playerDifficulty = .none }
                        )
                    }
                    
                    if playerDifficulty == .easy {
                        easyDetailChip(.player)
                            .padding(.top, 8)
                    }
                    
                    if playerDifficulty == .hard {
                        hardDetailChip(.player)
                            .padding(.top, 8)
                    }
                    
                    if playerDifficulty == .none {
                        skippedChip(.player)
                            .padding(.top, 8)
                    }
                }
                
                Spacer(minLength: 0)
                
                BigButton(
                    style: .solid,
                    title: "Draw",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: drawTapped
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .navigationBarTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    BackButton(icon: .xmark, onTap: { dismiss() })
                }
            }
            .edgesIgnoringSafeArea(.top)
            .padding(kPadding)
            .background(Color.systemCard)
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
            .onAppear() {
                teamDifficulty = viewModel.teamDifficulty
                playerDifficulty = viewModel.playerDifficulty
            }
        }
    }
    
    private func selectionButton(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        let gradient: LinearGradient = LinearGradient(
            colors: [
                isSelected ? kGameplayPack.style.primaryColor : Color.systemGray2,
                isSelected ? kGameplayPack.style.secondaryColor : Color.systemGray2],
            startPoint: .top,
            endPoint: .bottom)
        return Button(action: {
            Haptics.fire(.light)
            onTap()
        }) {
            VStack {
                Text(label)
                    .frame(height: 40)
                    .font(.dmSans(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? Color.systemBlack : Color.systemGray)
                    .alignCenter()
                    .background(isSelected ? kGameplayPack.style.primaryColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(gradient, lineWidth: 4)
                    )
                    .cornerRadius(10)
            }
        }
    }
    
    private func easyDetailChip(_ type: RuleType) -> some View {
        HStack(spacing: kPadding) {
            AwesomeImage(icon: .faceSmileHalo, style: .regular, size: 20, color: Color.systemGray)
            Group {
                Text("\(type == .team ? "Your team" : "Each player") rule will be ")
                + Text("favorable").bold()
                + Text(" or ")
                + Text("helpful").bold()
                + Text(" and give chance for better scoring.")
            }
            .font(.dmSans(size: 13))
            .foregroundColor(Color.systemGray)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .alignLeading()
        }
        .padding(kPadding)
        .background(Color.systemGray6)
        .cornerRadius(10)
    }
    
    private func hardDetailChip(_ type: RuleType) -> some View {
        HStack(spacing: kPadding) {
            AwesomeImage(icon: .faceSmileHorns, style: .regular, size: 20, color: Color.systemGray)
            Group {
                Text("\(type == .team ? "Your team" : "Each player") rule will be ")
                + Text("penalizing").bold()
                + Text(" or ")
                + Text("restrictive").bold()
                + Text(" and challenge \(type == .team ? "you" : "them") to score.")
            }
            .font(.dmSans(size: 13))
            .foregroundColor(Color.systemGray)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .alignLeading()
        }
        .padding(kPadding)
        .background(Color.systemGray6)
        .cornerRadius(10)
    }
    
    private func skippedChip(_ type: RuleType) -> some View {
        HStack(spacing: kPadding) {
            AwesomeImage(icon: .cardsBlank, style: .regular, size: 20, color: Color.systemGray)
            Group {
                Text("Your \(type.rawValue) rule\(type == .player ? "s" : "") will be ")
                + Text("skipped").bold()
                + Text(" for this hole.")
            }
            .font(.dmSans(size: 13))
            .foregroundColor(Color.systemGray)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
            .alignLeading()
        }
        .padding(kPadding)
        .background(Color.systemGray6)
        .cornerRadius(10)
    }
    
    private func drawTapped() {
        Task {
            viewModel.teamDifficulty = teamDifficulty
            viewModel.playerDifficulty = playerDifficulty
            await viewModel.draw()
        }
        dismiss()
    }
}

struct CustomizeGamePlayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack { }.sheet(isPresented: .true, onDismiss: {}, content: {
                CustomizeGamePlayView(viewModel: GameplayViewModel())
                    .presentationDetents([.height(650)])
                    .presentationDragIndicator(.visible)
            })
            .lightModePreview()
            
            VStack { }.sheet(isPresented: .true, onDismiss: {}, content: {
                CustomizeGamePlayView(viewModel: GameplayViewModel())
                    .presentationDetents([.height(650)])
                    .presentationDragIndicator(.visible)
            })
            .darkModePreview()
            
            VStack { }.sheet(isPresented: .true, onDismiss: {}, content: {
                CustomizeGamePlayView(viewModel: GameplayViewModel())
                    .presentationDetents([.height(650)])
                    .presentationDragIndicator(.visible)
            })
            .previewDevice("iPhone 8")
            .previewDisplayName("iPhone 8")
        }
    }
}
