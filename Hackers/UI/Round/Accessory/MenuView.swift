//
//  MenuView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import AlertToast
import SwiftUI

struct MenuView: View, Loggable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    @State private var showPartyCode: Bool = false
    @State private var showPartyCodeGenerated: Bool = false
    @State private var showPartyCodeTakenToast: Bool = false
    @State private var showWriteFailedToast: Bool = false
    @State private var showClipboardToast: Bool = false
    @State private var partyCode: String = ""
    
    @State private var maxScore: Int = 0
    @State private var showShare: Bool = false
    @State private var showLegal: Bool = false
    @State private var showEndRoundAlert: Bool = false
    
    var onPartyCode: OnPartyCodeChange?
    var onEnd: OnSelection?
    
    private var background: Color {
        colorScheme == .light ? .systemGray6 : .systemGray5
    }
    
    private var shareItem: String {
        partyCode.isEmpty
        ? kAppStoreURL
        : "Download the app and use party code '\(partyCode)' to join our round! \(kAppStoreURL)"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if let date = appSession.session?.createdAt.iso.dateFromISO8601 {
                Text("Round expires \(date.addingTimeInterval(86400).relativeTimeAgo)")
                    .font(.dmSans(size: 13, weight: .medium))
                    .foregroundColor(Color.systemGray)
                    .alignCenter()
            }
            
            Group {
                partyCodeButton
                shareLink
                maxScoreTile
            }

            Spacer(minLength: 0)
            
            PillDivider()

            Spacer(minLength: 0)

            Group {
                termsButton
                HStack(spacing: 12) {
                    endRoundButton
                    exitButton
                }
            }
            
            Text(Bundle.main.appVersion)
                .font(.dmSans(size: 10, weight: .bold))
                .foregroundColor(Color.systemGray)
                .alignCenter()
        }
        .environmentObject(appSession)
        .padding(.top, 8)
        .padding(16)
        .onAppear() {
            partyCode = appSession.sessionCode
            maxScore = deviceDefaults.maxScoreOverPar
        }
        .sheet(isPresented: $showLegal) { TermsView(onAccept: {}) }
        .toast(isPresenting: $showClipboardToast, alert: {
            AlertToast.messageBanner("Party code copied")
        })
        .toast(isPresenting: $showPartyCodeTakenToast, alert: {
            AlertToast.errorBanner("Party code already in use")
        })
        .toast(isPresenting: $showWriteFailedToast, alert: {
            AlertToast.errorBanner("Shank! Please try again.")
        })
        .alert("Party Code", isPresented: $showPartyCode, actions: {
            TextField("Type...", text: $partyCode)
                .font(.dmSans(size: 20, weight: .regular))
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.none)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
            Button(appSession.sessionCode.isEmpty ? "Create" : "Save", action: createCode)
            Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
        }, message: {
            Text("Make a fun party code for others to join the round from their devices!\n\nThis party code will be valid for 24 hours.")
        })
        .alert("End round?", isPresented: $showEndRoundAlert, actions: {
            Button("End", role: .destructive, action: endRoundTapped)
            Button("Cancel", role: .cancel, action: { Haptics.fire(.light) })
        }, message: {
            Text("This will end the round for your entire party.")
        })
    }
    
    // MARK: - Buttons
    
    private var partyCodeButton: some View {
        Button(action: { showPartyCode = true }) {
            VStack(spacing: 4) {
                if appSession.sessionCode.isEmpty {
                    Text("Generate party code")
                        .font(.dmSans(size: 16, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    
                    Text("Your party will be able to join this round and enjoy live scoring and card games.")
                        .font(.dmSans(size: 13, weight: .regular))
                        .foregroundColor(Color.systemGray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .alignCenter()
                } else {
                    Text(appSession.sessionCode)
                        .font(.dmSans(size: 32, weight: .bold))
                        .foregroundColor(Color.white)
                        .lineLimit(1)
                    
                    Text("This is your party code. Tap to modify.")
                        .font(.dmSans(size: 15, weight: .medium))
                        .foregroundColor(Color.white)
                        .lineLimit(1)
                        .alignCenter()
                }
            }
        }
        .padding()
        .background(appSession.sessionCode.isEmpty ? background : Color.systemGreenDark)
        .cornerRadius(12)
    }
    
    private var shareLink: some View {
        ShareLink(item: shareItem, label: {
            Text("Share Hackers with friends")
                .font(.dmSans(size: 16, weight: .medium))
                .foregroundColor(Color.systemBlack)
                .alignCenter()
                .padding()
                .frame(height: 50)
                .background(background)
                .cornerRadius(12)
        })
        .simultaneousGesture(TapGesture().onEnded() {
            Haptics.fire(.light)
            FirebaseEvent.shareWithFriendsTapped.log()
        })
    }
    
    private var maxScoreTile: some View {
        HStack(spacing: 12) {
            Text("Max score")
                .font(.dmSans(size: 16, weight: .medium))
                .foregroundColor(Color.systemBlack)
            
            Spacer()
            
            maxScoreButton(value: 3)
            maxScoreButton(value: 4)
            maxScoreButton(value: 5)
            maxScoreButton(value: 6)
        }
        .padding()
        .frame(height: 50)
        .background(background)
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func maxScoreButton(value: Int) -> some View {
        Button(action: {
            deviceDefaults.maxScoreOverPar = value
            maxScore = value
            Haptics.fire(.light)
        }) {
            Text("+\(value)")
                .font(.dmSans(size: 13, weight: .medium))
                .foregroundColor(
                    maxScore == value ? Color.systemHackersGreen : Color.systemGray
                )
                .frame(width: 36, height: 36)
                .background(
                    maxScore == value ? Color.systemHackersGreen.opacity(0.125) : Color.clear
                )
                .cornerRadius(18)
        }
    }
    
    private var termsButton: some View {
        Button(action: showTerms) {
            Text("Terms of Use")
                .font(.dmSans(size: 16, weight: .medium))
                .foregroundColor(Color.systemBlack)
                .alignCenter()
        }
        .padding()
        .frame(height: 50)
        .background(background)
        .cornerRadius(12)
    }
    
    private var exitButton: some View {
        Button(action: {
            Task(operation: appSession.clearRound)
            FirebaseEvent.exitToHome.log()
        }) {
            Text("Change round")
                .font(.dmSans(size: 16, weight: .medium))
                .foregroundColor(Color.systemBlack)
                .alignCenter()
        }
        .padding()
        .frame(height: 50)
        .background(background)
        .cornerRadius(12)
    }
    
    private var endRoundButton: some View {
        Button(action: {
            showEndRoundAlert = true
            FirebaseEvent.endRoundTapped.log()
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
    
    // MARK: - Functions
    
    private func createCode() {
        Haptics.fire(.light)
        let isNewCode = appSession.sessionCode.isEmpty
        
        Task {
            do {
                let s = try await appSession.verify(partyCode: partyCode.removeWhitespace).get()
                showPartyCodeGenerated = true
                
                if let a = onPartyCode { a!(s.code) }
                
                if isNewCode {
                    FirebaseEvent.shareCodeCreated.log()
                } else if s.code.isEmpty {
                    FirebaseEvent.shareCodeRemoved.log()
                } else {
                    FirebaseEvent.shareCodeEdited.log()
                }
                
                return
            } catch let error {
                print("error creating party code, \(error)")
                if let e = error as? HackersError {
                    if e == .partyCodeTaken {
                        Haptics.fire(.error)
                        showPartyCodeTakenToast = true
                        return
                    }
                    if e == .sessionWriteFailed {
                        Haptics.fire(.error)
                        showWriteFailedToast = true
                        return
                    }
                }
                showWriteFailedToast = true
            }
        }
    }
    
    private func showShareLink() {
        Haptics.fire(.light)
        showShare = true
    }
    
    private func showTerms() {
        Haptics.fire(.light)
        showLegal = true
    }
    
    private func endRoundTapped() {
        Haptics.fire(.light)
        if let a = onEnd { a!() }
    }
}

struct MenuView_Previews: PreviewProvider {
    static var view: some View {
        VStack {
            ForEach(0..<100, id: \.self) { i in
                Text("Background")
            }
        }
        .sheet(isPresented: .true) {
            MenuView()
                .environmentObject(AppSession())
                .presentationDetents([.height(adminMode ? 540 : 480)])
                .presentationDragIndicator(.visible)
        }
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
