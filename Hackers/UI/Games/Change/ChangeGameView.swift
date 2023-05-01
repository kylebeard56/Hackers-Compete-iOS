//
//  ChangeGameView.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import SwiftUI

struct ChangeGameView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var hole: Int
    
    @State private var selection: HackersGame = .traditional
    
    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            
            content
            
            Spacer(minLength: 0)
            
            BigButton(
                title: "Play game",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    viewModel.activeGame = selection
                    dismiss()
                }
            )
            .padding(.top, 8)
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 2)
        }
        .background(Color.systemViewBackground)
        .padding(.bottom, UIScreen.isSmall ? 8 : 0)
        .onAppear() {
            selection = viewModel.activeGame
        }
    }
    
    private var header: some View {
        VStack {
            HStack {
                Text("Change game")
                    .font(.fugazOne(size: 32))
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, onTap: {
                    dismiss()
                    Haptics.fire(.light)
                })
            }
            
            Text("Select the game or format to play:")
                .font(.dmSans(size: 17, weight: .medium))
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
        }
    }
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Ready to play")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                HStack(spacing: 12) {
                    ChangeGameTile(game: .traditional, selected: selection == .traditional, onTap: { select(.traditional) })
                    ChangeGameTile(game: .chaos, selected: selection == .chaos, onTap: { select(.chaos) })
                }
                
                Spacer(minLength: 0)
                    .frame(height: 8)
                
                Text("Coming soon")
                    .font(.dmSans(size: 17, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                
                HStack(spacing: 12) {
                    ChangeGameTile(game: .stableford, selected: selection == .stableford, onTap: { select(.stableford) })
                    ChangeGameTile(game: .vegas, selected: selection == .vegas, onTap: { select(.vegas) })
                }
                
                HStack(spacing: 12) {
                    ChangeGameTile(game: .football, selected: selection == .football, onTap: { select(.football) })
                    ChangeGameTile(game: .wolf, selected: selection == .wolf, onTap: { select(.wolf) })
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func select(_ value: HackersGame) {
        Haptics.fire(.light)
        self.selection = value
    }
}

struct ChangeGameView_Previews: PreviewProvider {
    static var view: some View {
        ChangeGameView(viewModel: RoundViewModel(), hole: 1)
            .environmentObject(AppSession())
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
