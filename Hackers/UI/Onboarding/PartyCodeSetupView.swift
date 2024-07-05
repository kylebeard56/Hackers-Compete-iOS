//
//  PartyCodeSetupView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Introspect
import SwiftUI

struct PartyCodeSetupView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.dismiss) var dismiss
    
    @State private var code: String = ""
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case field }
    
    var body: some View {
        VStack(spacing: 20) {
            Group {
                Text("Set your ")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
                + Text("**party code**")
                    .foregroundColor(Color.systemHackersGreen)
                    //.font(.dmSans, size: 17, weight: .bold)
                + Text(" so that others can join this round live from their own devices.")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
            }
            .font(.dmSans, size: 17)
            .alignLeading()
            
            TextField("Party code (recommended)", text: $code)
                .font(.dmSans, size: 20, weight: .regular)
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.return)
                .focused($focusedField, equals: .field)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                .modifier(BorderedTextFieldModifier(isActive: focusedField == .field))
            
            Text("Your party code is 100% made up by you, so pick something short and fun. Rounds only last 24 hours.")
                .foregroundColor(Color.systemGray)
                .font(.dmSans, size: 13, weight: .regular)
                .multilineTextAlignment(.leading)
                .alignLeading()
                .padding(.top, -10)
            
            errorBanners
            
            Spacer(minLength: 0)
            
            setupSummary
            
            VStack(spacing: 20) {
                Divider()

                BigButton(
                    title: "Start",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersGreen,
                    isDisabled: .false,
                    isLoading: $appSession.isCreatingNewRound
                )
                .onTapAsync {
                    await appSession.createNewRoundSession(with: code)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .navigationTitle("Create party code")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 28, weight: .bold)]
        })
        .onChange(of: code, perform: { _ in
            appSession.partyCodeTaken = false
            appSession.roundCreationError = false
        })
    }
    
    private var errorBanners: some View {
        Group {
            if appSession.partyCodeTaken {
                ErrorBanner(
                    title: "Already in use",
                    subtitle: "Someone else beat you to this code for the next 24 hours. Sorry!",
                    onTap: {
                        Haptics.fire(.light)
                        appSession.partyCodeTaken = false
                    }
                )
            }

            if appSession.roundCreationError {
                ErrorBanner(
                    title: "Round not started",
                    subtitle: "Something went wrong on our side. Please try again.",
                    onTap: {
                        Haptics.fire(.light)
                        appSession.roundCreationError = false
                    }
                )
            }
        }
    }
    
    private var setupSummary: some View {
        Group {
            Text("Your ")
                .foregroundColor(Color.systemBlack)
            + Text("**party of \(appSession.players.filter({ $0.isPlaying }).count)**")
                .foregroundColor(Color.systemHackersGreen)
            + Text(" is ready to play \(appSession.numberOfHoles) holes, starting on Hole \(appSession.startingHole).")
                .foregroundColor(Color.systemBlack)
//            + Text(" Your starting side game is ")
//                .foregroundColor(Color.systemBlack)
//            + Text("**\(appSession.sideGame.name)**")
//                .foregroundColor(Color.systemHackersPurple)
//            + Text(".")
//                .foregroundColor(Color.systemBlack)
        }
        .font(.dmSans, size: 15)
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(.center)
        .alignCenter()
    }
}

struct PartyCodeSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PartyCodeSetupView()
    }
}
