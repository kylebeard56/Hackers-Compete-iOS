//
//  ChaosCardsRulesView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/28/23.
//

import SwiftUI

struct ChaosCardsRulesView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var viewModel: RoundViewModel
    @StateObject var vm = ChaosViewModel()
    
    @State private var showRedrawCountView: Bool = false
    
    var isRedraw: Bool = false

    private let menuTint: Color = Color.systemBlack.opacity(0.69)
    private let menuScale: CGFloat = 0.9
    
    private var systemGrayMix: Color {
        colorScheme.isLight ? Color.systemGray3 : Color.systemGray2
    }
    
    private var redrawsMixed: Bool {
        vm.players.filter({ $0.chaosRedrawCount != vm.teamRedrawCount }).count > 0
    }
    
    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(.top, 8)
            content
                .padding(.top, 16)
        }
        .environmentObject(appSession)
        .padding(16)
        .background(Color.systemCard)
        .onAppear() {
            vm.teamRedrawCount = viewModel.teamRedrawCount
            vm.teamDifficulty = viewModel.teamDifficulty
            vm.players = viewModel.players
            vm.arrangement = viewModel.arrangement
        }
        .sheet(isPresented: $showRedrawCountView) {
            ChaosCardsRedrawView(viewModel: vm)
                .presentationDragIndicator(.visible)
                .presentationDetents([.height(540), .large])
        }
    }
    
    private var header: some View {
        VStack {
            HStack {
                Text("Rules")
                    .font(.fugazOne(size: 32))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }
            
            Text("Decide how your party would like to play *Cards of Chaos*.")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    private var content: some View {
        VStack(spacing: UIScreen.isSmall ? 12 : 16) {
            Group {                
                Text("On each hole, we want to draw")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                HStack(spacing: 12) {
                    button(
                        text: "team",
                        isSelected: viewModel.arrangement == .team,
                        onTap: {
                            viewModel.arrangement = .team
                            FirebaseEvent.chaosArrangementChanged.log()
                        }
                    )
                    button(
                        text: "player",
                        isSelected: viewModel.arrangement == .player,
                        onTap: {
                            viewModel.arrangement = .player
                            FirebaseEvent.chaosArrangementChanged.log()
                        }
                    )
                    button(
                        text: "combo",
                        isSelected: viewModel.arrangement == .combo,
                        onTap: {
                            viewModel.arrangement = .combo
                            FirebaseEvent.chaosArrangementChanged.log()
                        }
                    )
                }
                
                Text("cards and our game mood is")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                HStack(spacing: 12) {
                    button(
                        text: "generous",
                        isSelected: vm.teamDifficulty == .easy,
                        onTap: {
                            vm.teamDifficulty = .easy
                            FirebaseEvent.chaosDifficultyChanged.log()
                        }
                    )
                    button(
                        text: "frisky",
                        isSelected: vm.teamDifficulty == .medium,
                        onTap: {
                            vm.teamDifficulty = .medium
                            FirebaseEvent.chaosDifficultyChanged.log()
                        }
                    )
                    button(
                        text: "diabolical",
                        isSelected: vm.teamDifficulty == .hard,
                        onTap: {
                            vm.teamDifficulty = .hard
                            FirebaseEvent.chaosDifficultyChanged.log()
                        }
                    )
                }
                
                Text("and we could really use")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                if redrawsMixed {
                    HStack(spacing: 12) {
                        Button(action: {
                            showRedrawCountView = true
                            FirebaseEvent.chaosRedrawsMixed.log()
                            Haptics.fire(.light)
                        }) {
                            Text("a healthy mix of")
                            .font(.dmSans(size: 20, weight: .medium))
                            .foregroundColor(Color.systemHackersGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .alignCenter()
                            .padding(.horizontal, 6)
                            .frame(height: 44)
                            .background(Color.systemHackersGreen.opacity(0.125))
                            .border(Color.systemHackersGreen, width: 5, cornerRadius: 12)
                            .cornerRadius(12)
                        }
                        Button(action: {
                            vm.resetRedraws()
                            FirebaseEvent.chaosRedrawsCleared.log()
                            Haptics.fire(.light)
                        }) {
                            AwesomeImage(
                                rawIcon: "f2ed".unicode,
                                style: .regular,
                                size: 17,
                                color: systemGrayMix
                            )
                            .font(.dmSans(size: 20, weight: .medium))
                            .foregroundColor(systemGrayMix)
                            .frame(width: 44, height: 44)
                            .background(Color.clear)
                            .border(systemGrayMix, width: 5, cornerRadius: 12)
                            .cornerRadius(12)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        button(text: "0", isSelected: vm.teamRedrawCount == 0, onTap: {
                            vm.setRedraws(to: 0)
                            FirebaseEvent.chaosRedrawsChanged.log()
                        })
                        button(text: "1", isSelected: vm.teamRedrawCount == 1, onTap: {
                            vm.setRedraws(to: 1)
                            FirebaseEvent.chaosRedrawsChanged.log()
                        })
                        button(text: "2", isSelected: vm.teamRedrawCount == 2, onTap: {
                            vm.setRedraws(to: 2)
                            FirebaseEvent.chaosRedrawsChanged.log()
                        })
                        button(text: "3", isSelected: vm.teamRedrawCount == 3, onTap: {
                            vm.setRedraws(to: 3)
                            FirebaseEvent.chaosRedrawsChanged.log()
                        })
                        button(text: "4", isSelected: vm.teamRedrawCount == 4, onTap: {
                            vm.setRedraws(to: 4)
                            FirebaseEvent.chaosRedrawsChanged.log()
                        })
                        button(faIcon: "f303", isSelected: false, onTap: {
                            showRedrawCountView = true
                            FirebaseEvent.chaosRedrawsMixed.log()
                        })
                    }
                }
                
                Text("redraws for the game.")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
            }
            
            Spacer(minLength: 0)
            
            if isRedraw {
                BigButton(
                    style: .solid,
                    title: "Save and redraw",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { draw(shuffle: true) }
                )

                // Ensure user shuffles when arrangement of cards changes
                if vm.arrangement == viewModel.arrangement {
                    Button(action: {
                        draw(shuffle: false)
                        Haptics.fire(.light)
                    }) {
                        Text("Save and continue play")
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                            .alignCenter()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.systemGray6)
                            .cornerRadius(8)
                    }
                }

            } else {
                BigButton(
                    style: .solid,
                    title: "Save and play",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { draw(shuffle: true) }
                )
            }
        }
    }
    
    @ViewBuilder
    private func button(
        text: String? = nil,
        icon: String? = nil,
        faIcon: String? = nil,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: {
            onTap()
            Haptics.fire(.light)
        }) {
            Group {
                if let text {
                    Text(text)
                }
                if let icon {
                    Image(systemName: icon)
                }
                if let faIcon {
                    AwesomeImage(
                        rawIcon: faIcon.unicode,
                        style: .regular,
                        size: 17,
                        color: isSelected ? Color.systemHackersGreen : systemGrayMix
                    )
                }
            }
            .font(.dmSans(size: 20, weight: .medium))
            .foregroundColor(isSelected ? Color.systemHackersGreen : systemGrayMix)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .alignCenter()
            .padding(.horizontal, 6)
            .frame(height: 44)
            .background(isSelected ? Color.systemHackersGreen.opacity(0.125) : Color.clear)
            .border(isSelected ? Color.systemHackersGreen : systemGrayMix, width: 5, cornerRadius: 12)
            .cornerRadius(12)
        }
    }
    
    private func draw(shuffle: Bool = false) {
        print(#function)
        viewModel.teamDifficulty = vm.teamDifficulty
        viewModel.teamRedrawCount = vm.teamRedrawCount
        viewModel.players = vm.players
        
        if shuffle { Task(operation: viewModel.draw) }
        dismiss()
    }
}

struct ChaosCardsRulesView_Previews: PreviewProvider {
    static var view: some View {
        ZStack {
            Color.red
        }
        .sheet(isPresented: .true) {
            ChaosCardsRulesView(viewModel: RoundViewModel())
                .environmentObject(AppSession())
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
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
