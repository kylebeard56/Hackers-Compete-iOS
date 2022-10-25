//
//  PlayerEntry.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Introspect
import SwiftUI

struct PlayerEntry: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.dismiss) var dismiss
    
    @State private var oneActive: Bool = false
    @State private var twoActive: Bool = false
    @State private var threeActive: Bool = false
    @State private var fourActive: Bool = false
    @State private var fiveActive: Bool = false

    @State private var navigateToRound: Bool = false
    
    var body: some View {
        ZStack {
            ScrollView {
                content
            }
            
            BigButton(
                title: "Start round",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    navigateToRound = true
                    Haptics.fire(.light)
                }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 2)
            .padding(.horizontal, kPadding)
            .alignBottom()
            .ignoresSafeArea(.keyboard)
        }
        .navigationTitle("Who is playing?")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToRound, destination: { EmptyView() })
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.largeTitleTextAttributes = [.font: UIFont.dmSans(size: 40, weight: .bold)]
        })
    }
    
    private var content: some View {
        VStack(spacing: kPadding) {
            PlayerTextField(
                player: $appSession.players[0],
                placeholder: "Player One",
                isActive: $oneActive,
                onCommit: { twoActive = true })
            PlayerTextField(
                player: $appSession.players[1],
                placeholder: "Player Two",
                isActive: $twoActive,
                onCommit: { threeActive = true })
            PlayerTextField(
                player: $appSession.players[2],
                placeholder: "Player Three",
                isActive: $threeActive,
                onCommit: { fourActive = true })
            PlayerTextField(
                player: $appSession.players[3],
                placeholder: "Player Four",
                isActive: $fourActive,
                onCommit: { fiveActive = true })
            PlayerTextField(
                player: $appSession.players[4],
                placeholder: "Player Five",
                isActive: $fiveActive)
        }
        .padding(kPadding)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                if oneActive {
                    toolbar(color: $appSession.players[0].color)
                }
                if twoActive {
                    toolbar(color: $appSession.players[1].color)
                }
                if threeActive {
                    toolbar(color: $appSession.players[2].color)
                }
                if fourActive {
                    toolbar(color: $appSession.players[3].color)
                }
                if fiveActive {
                    toolbar(color: $appSession.players[4].color)
                }
            }
        }
    }
    
    // MARK: - Toolbar Shenanigans
    
    private func toolbar(color: Binding<Color>) -> some View {
        PlayerColorSelector(
            color: color,
            width: UIScreen.main.bounds.width * 0.55,
            diameter: 20,
            keyboardEmbedded: true
        )
    }
}

struct PlayerEntry_Previews: PreviewProvider {
    static var previews: some View {
        PlayerEntry().environmentObject(AppSession())
    }
}
