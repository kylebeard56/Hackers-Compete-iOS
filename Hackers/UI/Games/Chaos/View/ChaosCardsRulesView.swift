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
                    button(text: "team", isSelected: true, onTap: { })
                    button(text: "players", isSelected: false, onTap: { })
                    button(text: "both of us", isSelected: false, onTap: { })
                }
                
                Text("and we're feeling")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                // generous frisky diabolical
                HStack(spacing: 12) {
                    button(text: "generous", isSelected: true, onTap: { })
                    button(text: "frisky", isSelected: false, onTap: { })
                    button(text: "diabolical", isSelected: false, onTap: { })
                }
                
                Text("and we want")
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .alignLeading()
                
                // 0 1 2 3 4 pencil
                HStack(spacing: 12) {
                    button(text: "0", isSelected: true, onTap: { })
                    button(text: "1", isSelected: false, onTap: { })
                    button(text: "2", isSelected: false, onTap: { })
                    button(text: "3", isSelected: false, onTap: { })
                    button(text: "4", isSelected: false, onTap: { })
                    button(faIcon: "f303", isSelected: false, onTap: { showRedrawCountView = true })
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
                    onTap: {
                        // TODO: Set rules, redraw, and dismiss
                    }
                )

                Button(action: {
                    // TODO: Set rules, but dismiss
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
            } else {
                BigButton(
                    style: .solid,
                    title: "Save and play",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {
                        // TODO: Set rules, draw, and dismiss
                    }
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
        Button(action: onTap) {
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
                        color: isSelected ? Color.systemHackersGreen : Color.systemGray
                    )
                }
            }
            .font(.dmSans(size: 20, weight: .medium))
            .foregroundColor(isSelected ? Color.systemHackersGreen : Color.systemGray)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .alignCenter()
            .padding(.horizontal, 6)
            .frame(height: 44)
            .background(isSelected ? Color.systemHackersGreen.opacity(0.125) : Color.clear)
            .border(isSelected ? Color.systemHackersGreen : Color.systemGray, width: 5, cornerRadius: 12)
            .cornerRadius(12)
        }
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
