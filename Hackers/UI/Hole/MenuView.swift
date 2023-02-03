//
//  MenuView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import AlertToast
import SwiftUI

struct MenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    
    @State private var showRuleViewer: Bool = false
    
    @State private var showPartyCode: Bool = false
    @State private var showPartyCodeGenerated: Bool = false
    @State private var showPartyCodeTakenToast: Bool = false
    @State private var showWriteFailedToast: Bool = false
    @State private var partyCode: String = ""
    
    @State private var showPasswordView: Bool = false
    @State private var showPasswordWrongToast: Bool = false
    @State private var password: String = ""
    
    var onEnd: OnSelection?
    
    private var background: Color {
        colorScheme == .light ? .systemGray6 : .systemGray5
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if !appSession.sessionCode.isEmpty {
                VStack(spacing: 4) {
                    Text(appSession.sessionCode)
                        .font(.dmSans(size: 28, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                    
                    Text("Party code")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                }
            }
            
            Button(action: { showPartyCode = true }) {
                Text("\(appSession.sessionCode.isEmpty ? "Generate" : "Edit") party code")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(background)
            .cornerRadius(12)
            
            Button(action: viewRules) {
                Text("See all rules")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(background)
            .cornerRadius(12)
            
            Spacer(minLength: 0)
            
            Button(action: {
                if let a = onEnd { a!() }
            }) {
                Text("End round")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemRed)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(background)
            .cornerRadius(12)
        }
        .environmentObject(appSession)
        .padding(.top, kPadding / 2)
        .padding(kPadding)
        .onAppear() {
            partyCode = appSession.sessionCode
        }
        .fullScreenCover(isPresented: $showRuleViewer) { RuleViewer() }
        .toast(isPresenting: $showPartyCodeGenerated, alert: {
            AlertToast.messageBanner("Party code generated")
        })
        .toast(isPresenting: $showPartyCodeTakenToast, alert: {
            AlertToast.errorBanner("Party code already in use")
        })
        .toast(isPresenting: $showWriteFailedToast, alert: {
            AlertToast.errorBanner("Shank! Please try again.")
        })
        .toast(isPresenting: $showPasswordWrongToast, alert: {
            AlertToast.errorBanner("Yeah that's gonna be a no from me, dawg.")
        })
        .alert("List of Rules", isPresented: $showPasswordView, actions: {
            TextField("Enter password", text: $password)
                .font(.dmSans(size: 20, weight: .regular))
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.none)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
            Button("Submit", action: checkPassword)
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("Please enter the password to see all of the rules.")
        })
        .alert("Party Code", isPresented: $showPartyCode, actions: {
            TextField("Enter code", text: $partyCode)
                .font(.dmSans(size: 20, weight: .regular))
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.none)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
            Button("Create", action: createCode)
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("Create a fun party code for your group to join the round from their own devices. This party code will be valid for 24 hours!")
        })
    }
    
    private func viewRules() {
        if isPasswordVerified {
            showRuleViewer = true
        } else {
            showPasswordView = true
        }
    }
    
    private func checkPassword() {
        if password == "696969" {
            showRuleViewer = true
            isPasswordVerified = true
            password = ""
        } else {
            isPasswordVerified = false
            showPasswordWrongToast = true
        }
    }
    
    private func createCode() {
        Task {
            do {
                let s = try await appSession.verify(partyCode: partyCode).get()
                
            } catch let error {
                if let e = error as? HackersError {
                    if e == .partyCodeTaken {
                        print("code taken")
                    }
                    if e == .sessionWriteFailed {
                        print("fuck")
                    }
                }
                print("error creating party code, \(error)")
            }
        }
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ForEach(0..<100, id: \.self) { i in
                Text("Background")
            }
        }
        .sheet(isPresented: .true) {
            MenuView()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }
}
