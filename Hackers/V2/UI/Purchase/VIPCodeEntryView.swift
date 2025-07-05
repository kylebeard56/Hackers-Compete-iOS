//
//  VIPCodeEntryView.swift
//  Hackers
//
//  Created by Kyle Beard on 9/13/23.
//

import Introspect
import SwiftUI

struct VIPCodeEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var code: String = ""
    @State private var codeRejected: Bool = false
    @State private var codeAccepted: Bool = false
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case field }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Redeem code")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .introspectNavigationController(customize: { c in
                    c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
                })
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Group {
                Text("Enter the ")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
                + Text("**promo code**")
                    .foregroundColor(Color.systemHackersPurple)
                    //.font(.dmSans, size: 17, weight: .bold)
                + Text(" to redeem your free Pro membership.")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
            }
            .font(.dmSans, size: 17)
            .alignLeading()
            
            TextField("Promo code", text: $code)
                .font(.dmSans, size: 20, weight: .regular)
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.return)
                .focused($focusedField, equals: .field)
//                .introspect(.textField, on: .iOS(.v16, .v17)) { textField in
//                    textField.clearButtonMode = .whileEditing
//                }
                .modifier(BorderedTextFieldModifier(isActive: focusedField == .field))
            
            Text("Use of this code without expressed permission by Hackers is unlawful and subject to legal action.")
                .foregroundColor(Color.systemGray)
                .font(.dmSans, size: 13, weight: .regular)
                .multilineTextAlignment(.leading)
                .alignLeading()
                .padding(.top, -10)
            
            if codeRejected {
                ErrorBanner(
                    title: "Not so fast!",
                    subtitle: "This code is wrong. Double-check and try again.",
                    onTap: {
                        Haptics.fire(.light)
                        codeRejected = false
                    }
                )
            }
            
            Spacer(minLength: 0)
            
            VStack(spacing: 20) {
                Divider()

                if codeAccepted {
                    Button(action: {
                        Haptics.fire(.light)
                        dismiss()
                    }) {
                        VStack(spacing: 4) {
                            Text("You have unlocked Pro for life!")
                                .foregroundColor(Color.systemHackersPurple)
                                .font(.dmSans, size: 17, weight: .bold)
                                .alignLeading()

                            Text("Tap to dismiss.")
                                .foregroundColor(Color.systemHackersPurple)
                                .font(.dmSans, size: 13, weight: .regular)
                                .multilineTextAlignment(.leading)
                                .alignLeading()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                        .cornerRadius(12)
                    }
                } else {
                    BigButton(
                        title: "Redeem",
                        labelColor: .systemWhite,
                        buttonColor: .systemHackersPurple,
                        isDisabled: .false,
                        isLoading: .false
                    )
                    .onTap {
                        if code.uppercased() == vipCode.uppercased() {
                            codeAccepted = true
                            codeRejected = false
                            deviceDefaults.isLifetimeUnlocked = true
                        } else {
                            codeAccepted = false
                            codeRejected = true
                            deviceDefaults.isLifetimeUnlocked = false
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background(Color.systemViewBackground)
        .onAppear() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                focusedField = .field
            })
        }
        .onChange(of: code, perform: { _ in
            codeAccepted = false
            codeRejected = false
        })
    }
}

#Preview {
    VIPCodeEntryView()
}
