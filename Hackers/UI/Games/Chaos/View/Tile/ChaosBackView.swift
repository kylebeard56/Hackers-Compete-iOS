//
//  ChaosBackView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/27/23.
//

import AlertToast
import SwiftUI

struct ChaosBackView: View, Loggable {
    @State private var showRuleViewer: Bool = false
    @State private var showPasswordView: Bool = false
    @State private var showPasswordWrongToast: Bool = false
    @State private var password: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            content
            
            if adminMode {
                Button(action: viewRules) {
                    Text("Manage rules")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .alignCenter()
                        .background(Color.systemGray6)
                        .cornerRadius(8)
                }
            }
        }
        .fullScreenCover(isPresented: $showRuleViewer) { RuleViewer() }
        .toast(isPresenting: $showPasswordWrongToast, alert: {
            AlertToast.errorBanner("Nice try...")
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
    
    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(HackersGame.chaos.name)
                    .font(.fugazOne(size: UIScreen.isSmall ? 24 : 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
                
                Text("How to play")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                Text(
"""
This game gives your party a unique and amusing way to play each hole.

On each hole, your party draws cards that contain a random rule for how you can or cannot play the hole by influence scenarios involving club selection, ball advancement, or the treatment of certain terrains.

This game contains two types of cards - **favor** and **challenge**.

**Favor** cards are more helpful or supportive and grant opportunities to score.

**Challenge** cards are more penalizing or restrictive and test players to score.
"""
                )
                .font(.dmSans(size: 13, weight: .regular))
                .foregroundColor(Color.systemGray)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
        .alignTop()
    }
    
    private func viewRules() {
        Haptics.fire(.light)
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
            self.addBreadcrumb(.warning, .admin, "attempt to manage Cards of Chaos rules with wrong password")
        }
    }
}

struct ChaosBackView_Previews: PreviewProvider {
    static var view: some View {
        ZStack {
            Color.systemGray5.edgesIgnoringSafeArea(.all)
            ChaosBackView()
                .environmentObject(AppSession())
                .padding(16)
                .background(Color.systemWhite)
                .cornerRadius(12)
                .padding(16)
        }
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
