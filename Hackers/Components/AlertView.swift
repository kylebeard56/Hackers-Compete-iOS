//
//  AlertView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

struct AlertView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var alert: HackersAlert
    var onTap: OnSelection
    var onDismiss: OnSelection
    
    @State private var animateBackground: Bool = false
    @State private var animateAlert: Bool = false
    
    let kBackgroundAnimationTime: CGFloat = 0.125
    let kAlertAnimationTime: CGFloat = 0.0625
    
    var body: some View {
        ZStack {
            if animateBackground {
                Blur(style: colorScheme == .light ? .light : .dark).opacity(0.4)
                Color.black.opacity(0.6)
            }
            
            VStack(spacing: 8) {
                Text(alert.title)
                    .font(.dmSans, size: 22, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .multilineTextAlignment(.center)

                if let message = alert.message {
                    Text(message)
                        .font(.dmSans, size: 15, weight: .regular)
                        .foregroundColor(Color.systemGray)
                        .multilineTextAlignment(.center)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Group {
                    if let primaryText = alert.primaryText, alert.isMultiButton {
                        HStack(spacing: 16) {
                            multiDismissButton
                            multiActionButton(primaryText)
                        }
                    } else {
                        singleDismissButton
                    }
                }
            }
            .padding(16)
            .background(Color.systemCard)
            .cornerRadius(8)
            .padding(32)
            .scaleEffect(animateAlert ? 1 : 0)
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear() {
            showWithAnimations()
        }
    }
    
    private var singleDismissButton: some View {
        Button(action: dismiss) {
            HStack {
                Spacer()
                Text(alert.dismissText)
                    .font(.dmSans, size: 17, weight: .medium)
                    .foregroundColor(Color.white)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(Color.systemBlue)
            .cornerRadius(8)
        }
        .buttonStyle(BorderlessButtonStyle())
    }
    
    private var multiDismissButton: some View {
        Button(action: dismiss) {
            Text(alert.dismissText)
                .font(.dmSans, size: 17, weight: .medium)
                .foregroundColor(Color.systemBlack)
                .padding(.horizontal, 32)
                .padding(.vertical, 8)
        }.buttonStyle(ChipButtonStyle())
    }
    
    private func multiActionButton(_ text: String) -> some View {
        Button(action: tap) {
            HStack {
                Spacer()
                Text(text)
                    .font(.dmSans, size: 17, weight: .medium)
                    .foregroundColor(Color.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(alert.isDestructive ? Color.systemRed : Color.systemBlue)
            .cornerRadius(8)
        }
    }
    
    private func tap() {
        if let tap = onTap {
            tap()
        }
    }
    
    private func dismiss() {
        if let dismiss = onDismiss {
            hideWithAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + kBackgroundAnimationTime, execute: {
                dismiss()
            })
        }
    }
    
    private func showWithAnimations() {
        withAnimation(.easeInOut(duration: kBackgroundAnimationTime)) {
            self.animateBackground = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + kBackgroundAnimationTime, execute: {
            withAnimation(.interactiveSpring()) {
                self.animateAlert = true
            }
        })
    }
    
    private func hideWithAnimations() {
        withAnimation(.interactiveSpring()) {
            self.animateAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + kAlertAnimationTime, execute: {
            withAnimation(.easeInOut(duration: kBackgroundAnimationTime)) {
                self.animateBackground = true
            }
        })
    }
}

struct AlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Group {
                AlertView(alert: .generic, onTap: { }, onDismiss: { })
                AlertView(alert: .previewTest, onTap: { }, onDismiss: { })
                AlertView(alert: .previewTestDestructive, onTap: { }, onDismiss: { })
            }.preferredColorScheme(.light)
            
            Group {
                AlertView(alert: .generic, onTap: { }, onDismiss: { })
                AlertView(alert: .previewTest, onTap: { }, onDismiss: { })
                AlertView(alert: .previewTestDestructive, onTap: { }, onDismiss: { })
            }.preferredColorScheme(.dark)
        }
    }
}
