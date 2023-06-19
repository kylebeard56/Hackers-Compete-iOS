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
                        .font(.dmSans(size: 17, weight: .regular))
                    + Text("party code")
                        .foregroundColor(Color.systemHackersGreen)
                        .font(.dmSans(size: 17, weight: .bold))
                    + Text(" set for your round.")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 17, weight: .regular))
                }
                .alignLeading()
                
                TextField("Party code", text: $appSession.sessionCode)
                    .font(.dmSans(size: 20, weight: .regular))
                    .keyboardType(.alphabet)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.return)
                    .focused($focusedField, equals: .field)
                    .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                    .modifier(BorderedTextFieldModifier(isActive: focusedField == .field))

                if appSession.sessionCodeError == .expired {
                    VStack {
                        Text("This round has expired")
                            .foregroundColor(Color.white)
                            .font(.dmSans(size: 17, weight: .regular))
                            .alignLeading()
                        
                        Text("Rounds are only active for 24 hours. Please play a new round.")
                            .foregroundColor(Color.white)
                            .font(.dmSans(size: 13, weight: .regular))
                            .multilineTextAlignment(.leading)
                            .alignLeading()
                    }
                    .padding(10)
                    .background(Color.systemError)
                    .cornerRadius(10)
                }
                
                if appSession.sessionCodeError == .notFound {
                    VStack {
                        Text("Round not found")
                            .foregroundColor(Color.white)
                            .font(.dmSans(size: 17, weight: .bold))
                            .alignLeading()
                        
                        Text("Double-check the code you entered. Party codes are case sensitive.")
                            .foregroundColor(Color.white)
                            .font(.dmSans(size: 13, weight: .regular))
                            .multilineTextAlignment(.leading)
                            .alignLeading()
                    }
                    .padding(10)
                    .background(Color.systemError)
                    .cornerRadius(10)
                }
                
                Spacer(minLength: 0)
                
                BigButton(
                    title: "Continue",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersGreen,
                    isDisabled: .constant(appSession.sessionCode.isEmpty),
                    isLoading: $appSession.isJoiningWithPartyCode,
                    onTap: validateSessionCode
                )
            }
            .navigationTitle("Join with Code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton(
                        icon: .xmark,
                        onTap: { dismiss() }
                    )
                    .alignTrailing()
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
        }
        .environmentObject(appSession)
        .background(Color.systemViewBackground)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                self.focusedField = .field
            })
        }
    }
    
    private func validateSessionCode() {
        print(#function)
        Task(operation: appSession.fetchSessionFromPartyCode)
    }
}

struct JoinWithCodeView_Previews: PreviewProvider {
    static var previews: some View {
        JoinWithCodeView()
    }
}
