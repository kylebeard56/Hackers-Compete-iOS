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
    
    @State private var showWaitlistEntry: Bool = false
    
    var body: some View {
        content
//            .observeToast(for: $viewModel.waitlistToast)
            .alert("Join the waitlist", isPresented: $showWaitlistEntry, actions: {
                TextField("Enter your email", text: $viewModel.waitlistEmail)
                    .font(.dmSans(size: 17, weight: .regular))
                    .keyboardType(.emailAddress)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.none)
                    .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                Button("Join", action: {
                    Haptics.fire(.light)
                    Task(operation: viewModel.joinWaitlist)
                })
                Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
            }, message: {
                Text("Get notified by email for updates around when the drinking pack will become available.")
            })
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("The Drinking Pack")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                
                VStack(spacing: 2) {
                    Text("The one thing better than hitting a great shot is")
                    Text("making someone drink because you did it.")
                        .bold()
                }
                .font(.dmSans(size: 15, weight: .regular))
                .foregroundColor(Color.systemGrayDark)
            }
            
            Spacer(minLength: 0)
 
            if viewModel.isOnWaitlist {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(appSession.drinkingPack.style.linearGradient, lineWidth: 3)
                            .frame(width: 40, height: 40)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(appSession.drinkingPack.style.linearGradient.opacity(0.125))
                            .frame(width: 40, height: 40)
                        
                        AwesomeImage(
                            icon: .golfBallTee,
                            style: .regular,
                            size: 20,
                            color: appSession.drinkingPack.style.primaryColor,
                            secondaryColor: appSession.drinkingPack.style.secondaryColor,
                            startPoint: .top,
                            endPoint: .bottom)
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(appSession.drinkingPack.style.linearGradient, lineWidth: 3)
                            .frame(width: 56, height: 56)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(appSession.drinkingPack.style.linearGradient.opacity(0.125))
                            .frame(width: 56, height: 56)
                        
                        AwesomeImage(
                            icon: .beerMug,
                            style: .regular,
                            size: 28,
                            color: appSession.drinkingPack.style.primaryColor,
                            secondaryColor: appSession.drinkingPack.style.secondaryColor,
                            startPoint: .top,
                            endPoint: .bottom)
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(appSession.drinkingPack.style.linearGradient, lineWidth: 3)
                            .frame(width: 72, height: 72)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(appSession.drinkingPack.style.linearGradient.opacity(0.125))
                            .frame(width: 72, height: 72)
                        
                        AwesomeImage(
                            rawIcon: "f0e0".unicode,
                            style: .regular,
                            size: 36,
                            color: appSession.drinkingPack.style.primaryColor,
                            secondaryColor: appSession.drinkingPack.style.secondaryColor,
                            startPoint: .top,
                            endPoint: .bottom)
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(appSession.drinkingPack.style.linearGradient, lineWidth: 3)
                            .frame(width: 56, height: 56)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(appSession.drinkingPack.style.linearGradient.opacity(0.125))
                            .frame(width: 56, height: 56)
                        
                        AwesomeImage(
                            rawIcon: "f561".unicode,
                            style: .regular,
                            size: 28,
                            color: appSession.drinkingPack.style.primaryColor,
                            secondaryColor: appSession.drinkingPack.style.secondaryColor,
                            startPoint: .top,
                            endPoint: .bottom)
                    }
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(appSession.drinkingPack.style.linearGradient, lineWidth: 3)
                            .frame(width: 40, height: 40)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(appSession.drinkingPack.style.linearGradient.opacity(0.125))
                            .frame(width: 40, height: 40)
                        
                        AwesomeImage(
                            icon: .golfClub,
                            style: .regular,
                            size: 20,
                            color: appSession.drinkingPack.style.primaryColor,
                            secondaryColor: appSession.drinkingPack.style.secondaryColor,
                            startPoint: .top,
                            endPoint: .bottom)
                    }
                }
                .padding(.vertical, 24)
                
                VStack(spacing: 12) {
                    Text("You're on the waitlist!")
                        .font(.dmSans(size: 22, weight: .bold))
                        .foregroundStyle(appSession.drinkingPack.style.linearGradient)
                        .alignCenter()
                    
                    PillDivider()
                    
                    Text("We'll notify you with updates when the drinking pack is available.")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.systemGrayDark)
                        .multilineTextAlignment(.center)
                        .alignCenter()
                }

            } else {
                GradientButton(
                    title: "Join the waitlist",
                    subtitle: "This game is currently under construction.",
                    awesomeIcon: "e0b3",
                    labelTint: .systemBlack,
                    backgroundTint: .systemCard,
                    primaryTint: appSession.drinkingPack.style.primaryColor,
                    secondaryTint: appSession.drinkingPack.style.secondaryColor,
                    iconSize: 72,
                    fontSize: 28,
                    radius: 12,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { showWaitlistEntry = true }
                )
            }

        }
        .padding(.horizontal, 16)
    }
}

struct DrinkingView_Previews: PreviewProvider {
    static var previews: some View {
        DrinkingView(viewModel: RoundViewModel())
            .environmentObject(AppSession())
    }
}
