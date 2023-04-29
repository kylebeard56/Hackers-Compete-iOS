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
        vm.players.filter({ $0.redrawCount != vm.teamRedrawCount }).count > 0
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
        ZStack {
            Text("Cards of Chaos")
                .font(.fugazOne(size: 20))
                .foregroundColor(Color.systemHackersGreen)
                .alignCenter()
            
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
        }
    }
    
    private var content: some View {
        VStack(spacing: UIScreen.isSmall ? 12 : 16) {
            Group {
                Text("On each hole,")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                Text("we want to draw cards for the")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                // team players both of us
                HStack(spacing: 12) {
                    button(
                        text: "team",
                        isSelected: viewModel.arrangement == .team,
                        onTap: { viewModel.arrangement = .team }
                    )
                    button(
                        text: "players",
                        isSelected: viewModel.arrangement == .player,
                        onTap: { viewModel.arrangement = .player }
                    )
                    button(
                        text: "both of us",
                        isSelected: viewModel.arrangement == .both,
                        onTap: { viewModel.arrangement = .both }
                    )
                }
                
                Text("and we're feeling")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                // generous frisky diabolical
                HStack(spacing: 12) {
                    button(
                        text: "generous",
                        isSelected: vm.teamDifficulty == .easy,
                        onTap: { vm.teamDifficulty = .easy }
                    )
                    button(
                        text: "frisky",
                        isSelected: vm.teamDifficulty == .medium,
                        onTap: { vm.teamDifficulty = .medium }
                    )
                    button(
                        text: "diabolical",
                        isSelected: vm.teamDifficulty == .hard,
                        onTap: { vm.teamDifficulty = .hard }
                    )
                }
                
                Text("and we want")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                if redrawsMixed {
                    HStack(spacing: 12) {
                        Button(action: {
                            showRedrawCountView = true
                            Haptics.fire(.light)
                        }) {
                            Text("a mixed amount of")
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
                        button(text: "0", isSelected: vm.teamRedrawCount == 0, onTap: { vm.setRedraws(to: 0) })
                        button(text: "1", isSelected: vm.teamRedrawCount == 1, onTap: { vm.setRedraws(to: 1) })
                        button(text: "2", isSelected: vm.teamRedrawCount == 2, onTap: { vm.setRedraws(to: 2) })
                        button(text: "3", isSelected: vm.teamRedrawCount == 3, onTap: { vm.setRedraws(to: 3) })
                        button(text: "4", isSelected: vm.teamRedrawCount == 4, onTap: { vm.setRedraws(to: 4) })
                        button(faIcon: "f303", isSelected: false, onTap: { showRedrawCountView = true })
                    }
                }
                
                Text("redraws for the game.")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemGray)
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
