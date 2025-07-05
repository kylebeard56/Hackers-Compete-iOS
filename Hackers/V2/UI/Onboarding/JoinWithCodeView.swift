//
//  JoinWithCodeView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/23.
//

import Introspect
import SwiftUI

enum SessionCodeError: String {
    case expired = "This round has expired"
    case notFound = "No rounds found for this code"
    case none = ""
}

struct JoinWithCodeView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.dismiss) var dismiss
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case field }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    Text("Enter the ")
                        .foregroundColor(Color.systemBlack)
                        //.font(.dmSans, size: 17, weight: .regular)
                    + Text("**party code**")
                        .foregroundColor(Color.systemHackersGreen)
                        //.font(.dmSans, size: 17, weight: .bold)
                    + Text(" set for your round.")
                        .foregroundColor(Color.systemBlack)
                        //.font(.dmSans, size: 17, weight: .regular)
                }
                .font(.dmSans, size: 17)
                .alignLeading()
                .padding(.horizontal, 20)
                
                TextField("Party code", text: $appSession.sessionCode)
                    .font(.dmSans, size: 20, weight: .regular)
                    .keyboardType(.alphabet)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.return)
                    .focused($focusedField, equals: .field)
                    .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                    .modifier(BorderedTextFieldModifier(isActive: focusedField == .field))
                    .padding(.horizontal, 20)
                
                if appSession.sessionCodeError == .expired {
                    ErrorBanner(
                        title: "This round has expired",
                        subtitle: "Rounds are only active for 24 hours. Please play a new round.",
                        onTap: {
                            Haptics.fire(.light)
                            appSession.sessionCodeError = .none
                        }
                    )
                    .padding(.horizontal, 20)
                }
                
                if appSession.sessionCodeError == .notFound {
                    ErrorBanner(
                        title: "Round not found",
                        subtitle: "Double-check the code you entered. Party codes are case sensitive.",
                        onTap: {
                            Haptics.fire(.light)
                            appSession.sessionCodeError = .none
                        }
                    )
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 0)
                
                VStack(spacing: 20) {
                    Divider()
                    
                    BigButton(
                        title: "Continue",
                        labelColor: .systemWhite,
                        buttonColor: .systemHackersGreen,
                        isDisabled: .constant(appSession.sessionCode.isEmpty),
                        isLoading: $appSession.isJoiningWithPartyCode
                    )
                    .onTapAsync {
                        await appSession.fetchSessionFromPartyCode()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            .navigationTitle("Join with code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 28, weight: .bold)]
            })
        }
        .environmentObject(appSession)
        .background(Color.systemViewBackground)
        .padding(.top, 10)
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                self.focusedField = .field
            })
        }
        .onReceive(appSession.$sessionCode, perform: { _ in appSession.sessionCodeError = .none })
    }
}

struct JoinWithCodeView_Previews: PreviewProvider {
    static var previews: some View {
        JoinWithCodeView()
    }
}
