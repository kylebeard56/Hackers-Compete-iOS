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
            .resignKeyboardOnTapGesture()
            
            BigButton(
                title: "Start round",
                labelColor: .systemWhite,
                buttonColor: .systemBlack,
                isDisabled: $appSession.arePlayersEmpty,
                isLoading: .false,
                onTap: { navigateToRound = true }
            )
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 2)
            .padding(.horizontal, kPadding)
            .padding(.vertical, kPadding / 2)
            .alignBottom()
            .ignoresSafeArea(.keyboard)
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationTitle("Who is playing?")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToRound, destination: { HoleView() })
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
        })
    }
    
    private var content: some View {
        VStack(spacing: kPadding) {
            PlayerTextField(player: $appSession.players[0], placeholder: "Player 1", onFocus: { focus in
                oneActive = focus
            })
            PlayerTextField(player: $appSession.players[1], placeholder: "Player 2", onFocus: { focus in
                twoActive = focus
            })
            PlayerTextField(player: $appSession.players[2], placeholder: "Player 3", onFocus: { focus in
                threeActive = focus
            })
            PlayerTextField(player: $appSession.players[3], placeholder: "Player 4", onFocus: { focus in
                fourActive = focus
            })
            PlayerTextField(player: $appSession.players[4], placeholder: "Player 5 (it happens, we know)", onFocus: { focus in
                fiveActive = focus
            })
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
            width: UIScreen.main.bounds.width * 0.65, // Note: No idea why 65% of full width worked here...
            diameter: 20,
            keyboardEmbedded: true
        )
    }
}

struct PlayerEntry_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                PlayerEntry()
                    .environmentObject(AppSession())
            }
            .lightModePreview()
            NavigationStack {
                PlayerEntry()
                    .environmentObject(AppSession())
            }
            .darkModePreview()
        }
    }
}
