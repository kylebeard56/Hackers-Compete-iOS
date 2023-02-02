//
//  DrinkingView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/26/22.
//

import Introspect
import SwiftUI

struct DrinkingView: View {
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    @State private var showEmail: Bool = false
    @State private var email: String = ""
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case email }
    
    var body: some View {
        ZStack {
            content
            if showEmail {
                VStack {
                    Spacer()
                    joinWaitlistPopup
                        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 0)
                    Spacer()
                }
            }
        }
        .environmentObject(appSession)
    }
    
    private var content: some View {
        VStack(spacing: kPadding) {
            VStack(spacing: 8) {
                Text("The Drinking Pack")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                VStack(spacing: 2) {
                    Text("The only thing better than hitting a great shot is")
                    Text("making your buddies drink because you did it.").bold()
                }
                .font(.dmSans(size: 15, weight: .regular))
                .foregroundColor(Color.systemGrayDark)
            }
            .padding(.horizontal, kPadding)
           
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.systemGray6)
                
                VStack {
                    Text("Coming soon")
                        .font(.dmSans(size: 28, weight: .bold))
                        .foregroundStyle(appSession.drinkingPack.style.linearGradient)
                    Text("When we sober up, we'll open our waitlist")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemGray)
                }

            }
            .padding(kPadding)

//            Spacer(minLength: 0)
//
//            BigButton(
//                style: .solid,
//                title: "Join the waitlist",
//                labelColor: Color.systemWhite,
//                buttonColor: Color.systemBlack,
//                isDisabled: .false,
//                isLoading: .false,
//                onTap: waitlistTapped
//            )
//            .padding(.horizontal, kPadding)
//            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
    }
    
    private var joinWaitlistPopup: some View {
        VStack {
            VStack(spacing: 4) {
                Text("Join the waitlist")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemBlack)

                Text("You'll receive an email when the drinking pack is available!")
                    .font(.dmSans(size: 12, weight: .medium))
                    .foregroundColor(Color.systemGray)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
                    .padding(.trailing, 48)
                    .padding(.bottom, 8)
                
                TextField("Email", text: $email, onCommit: clearEmail)
                    .font(.dmSans(size: 22, weight: .medium))
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.return)
                    .focused($focusedField, equals: .email)
                
                HStack(spacing: kPadding) {
                    Button(action: clearEmail) {
                        Text("Close")
                            .font(.dmSans(size: 15, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignCenter()
                            .padding(.horizontal, kPadding)
                            .padding(.vertical, 12)
                            .background(Color.systemGray5)
                            .cornerRadius(8)
                    }
                    Button(action: {
                        print("todo: save email in viewmodel and also save user default")
                        Haptics.fire(.light)
                    }) {
                        Text("Join")
                            .font(.dmSans(size: 15, weight: .medium))
                            .foregroundColor(Color.systemWhite)
                            .alignCenter()
                            .padding(.horizontal, kPadding)
                            .padding(.vertical, 12)
                            .background(Color.systemBlack)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(kPadding)
            .background(Color.systemCard)
            .cornerRadius(8)
        }
        .padding(kPadding)
    }
    
    private func waitlistTapped() {
        Haptics.fire(.light)
        showEmail = true
        focusedField = .email
        email = ""
    }
    
    private func clearEmail() {
        Haptics.fire(.light)
        showEmail = false
        focusedField = nil
        email = ""
    }
}

struct DrinkingView_Previews: PreviewProvider {
    static var previews: some View {
        DrinkingView(viewModel: RoundViewModel())
            .environmentObject(AppSession())
    }
}
