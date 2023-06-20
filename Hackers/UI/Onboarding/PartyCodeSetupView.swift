//
//  PartyCodeSetupView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Introspect
import SwiftUI

enum PartyCodeError { case taken, saveFailed, none }

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
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("party code")
                    .foregroundColor(Color.systemHackersGreen)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" so that others can join this round live from their own devices.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .alignLeading()
            
            TextField("Party code (recommended)", text: $code)
                .font(.dmSans(size: 20, weight: .regular))
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.return)
                .focused($focusedField, equals: .field)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                .modifier(BorderedTextFieldModifier(isActive: focusedField == .field))
                .onTapGesture { Haptics.fire(.light) }
            
            Text("Your party code is 100% made up by you, so pick something short and fun. Rounds only last 24 hours.")
                .foregroundColor(Color.systemGray)
                .font(.dmSans(size: 13, weight: .regular))
                .multilineTextAlignment(.leading)
                .alignLeading()
                .padding(.top, -10)
            
            if appSession.partyCodeError == .taken {
                ErrorBanner(
                    title: "Already in use",
                    subtitle: "Someone else beat you to this code for the next 24 hours. Sorry!",
                    onTap: {
                        Haptics.fire(.light)
                        appSession.partyCodeError = .none
                    }
                )
            }

            if appSession.partyCodeError == .saveFailed {
                ErrorBanner(
                    title: "Code not saved",
                    subtitle: "Something went wrong on our side. Please try again or setup later.",
                    onTap: {
                        Haptics.fire(.light)
                        appSession.partyCodeError = .none
                    }
                )
            }
            
            Spacer(minLength: 0)
            
            VStack(spacing: 20) {
                Divider()
                
                BigButton(
                    title: "Start",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersGreen,
                    isDisabled: .false,
                    isLoading: $appSession.isVerifyingPartyCode
                )
                .onTapAsync {
                    if code.isEmpty {
                        appSession.goToRoundPlay()
                    } else {
                        await appSession.verifyPartyCode(code)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background(Color.systemViewBackground)
        .navigationTitle("Add your party")
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
        .onChange(of: code, perform: { _ in appSession.partyCodeError = .none })
    }
}

struct PartyCodeSetupView_Previews: PreviewProvider {
    static var previews: some View {
        PartyCodeSetupView()
    }
}
