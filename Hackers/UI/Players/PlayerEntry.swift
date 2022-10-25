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
    
    @StateObject var viewModel = PlayerViewModel()
    
    @State private var toolbarColor: Color = Color.systemBlue
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
            
            //NavigationLink("", isActive: $goToNext, destination: { CreatePostPlace(viewModel: viewModel) })
        }
        .navigationTitle("Who is playing?")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
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
                player: $viewModel.playerOne,
                placeholder: "Player One",
                isActive: $viewModel.oneActive,
                onCommit: { viewModel.twoActive = true })
            PlayerTextField(
                player: $viewModel.playerTwo,
                placeholder: "Player Two",
                isActive: $viewModel.twoActive,
                onCommit: { viewModel.threeActive = true })
            PlayerTextField(
                player: $viewModel.playerThree,
                placeholder: "Player Three",
                isActive: $viewModel.threeActive,
                onCommit: { viewModel.fourActive = true })
            PlayerTextField(
                player: $viewModel.playerFour,
                placeholder: "Player Four",
                isActive: $viewModel.fourActive,
                onCommit: { viewModel.fiveActive = true })
            PlayerTextField(
                player: $viewModel.playerFive,
                placeholder: "Player Five",
                isActive: $viewModel.fiveActive)
        }
        .padding(kPadding)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                //toolbar()
                if viewModel.oneActive {
                    toolbar(color: $viewModel.playerOne.color)
                }
                if viewModel.twoActive {
                    toolbar(color: $viewModel.playerTwo.color)
                }
                if viewModel.threeActive {
                    toolbar(color: $viewModel.playerThree.color)
                }
                if viewModel.fourActive {
                    toolbar(color: $viewModel.playerFour.color)
                }
                if viewModel.fiveActive {
                    toolbar(color: $viewModel.playerFive.color)
                }
            }
        }
    }
    
    var _body: some View {
        VStack(spacing: kPadding) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: kPadding) {
                    PlayerTextField(
                        player: $viewModel.playerOne,
                        placeholder: "Player One",
                        isActive: $viewModel.oneActive,
                        onCommit: { viewModel.twoActive = true })
                    PlayerTextField(
                        player: $viewModel.playerTwo,
                        placeholder: "Player Two",
                        isActive: $viewModel.twoActive,
                        onCommit: { viewModel.threeActive = true })
                    PlayerTextField(
                        player: $viewModel.playerThree,
                        placeholder: "Player Three",
                        isActive: $viewModel.threeActive,
                        onCommit: { viewModel.fourActive = true })
                    PlayerTextField(
                        player: $viewModel.playerFour,
                        placeholder: "Player Four",
                        isActive: $viewModel.fourActive,
                        onCommit: { viewModel.fiveActive = true })
                    PlayerTextField(
                        player: $viewModel.playerFive,
                        placeholder: "Player Five",
                        isActive: $viewModel.fiveActive)
                }
                .toolbar {
                    ToolbarItem(placement: .keyboard) {
                        //toolbar()
                        if viewModel.oneActive {
                            toolbar(color: $viewModel.playerOne.color)
                        }
                        if viewModel.twoActive {
                            toolbar(color: $viewModel.playerTwo.color)
                        }
                        if viewModel.threeActive {
                            toolbar(color: $viewModel.playerThree.color)
                        }
                        if viewModel.fourActive {
                            toolbar(color: $viewModel.playerFour.color)
                        }
                        if viewModel.fiveActive {
                            toolbar(color: $viewModel.playerFive.color)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
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
            .ignoresSafeArea(.keyboard) // TODO: This doesn't work (sigh)
        }
        .padding(kPadding)
        .navigationTitle("Who is playing?")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.largeTitleTextAttributes = [.font: UIFont.dmSans(size: 40, weight: .bold)]
        })
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
