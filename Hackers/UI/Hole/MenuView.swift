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
    @State private var showComingSoonToast: Bool = false
    
    @State private var showPasswordView: Bool = false
    @State private var showPasswordWrongToast: Bool = false
    @State private var password: String = ""
    
    var onEnd: OnSelection?
    
    private var background: Color {
        colorScheme == .light ? .systemGray6 : .systemGray5
    }
    
    var body: some View {
        VStack(spacing: 12) {
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
            
            Button(action: { showComingSoonToast = true }) {
                Text("Edit players")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(background)
            .cornerRadius(12)
            
            Button(action: { showComingSoonToast = true }) {
                Text("Discover golf formats")
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
        .fullScreenCover(isPresented: $showRuleViewer) { RuleViewer() }
        .toast(isPresenting: $showComingSoonToast, alert: {
            AlertToast.messageBanner("Coming soon!")
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
