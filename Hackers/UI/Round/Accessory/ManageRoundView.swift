//
//  ManageRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/6/23.
//

import SwiftUI

struct ManageRoundView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    @State private var showPartyCode: Bool = false
    @State private var maxScore: Int = 0
    @State private var hapticsEnabled: Bool = false
    @State private var pushNotificationsEnabled: Bool = false
    @State private var showTerms: Bool = false
    @State private var showExpirationInfo: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Settings")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 20) {
                    hackersPro
                        .padding(.vertical, 10)
                    rows
                }
            }
            
            if let date = appSession.session?.createdAt.iso.dateFromISO8601 {
                InfoBanner(
                    icon: "f017",
                    text: "This round expires \(date.addingTimeInterval(86400).relativeTimeAgo).",
                    backgroundColor: colorScheme.superlightGray,
                    onTap: {
                        showExpirationInfo = true
                        Haptics.fire(.light)
                    }
                )
                .padding(.horizontal, 20)
            }
            
            Divider()
            
            Button(action: {
                Task { await appSession.leaveRound() }
                Haptics.fire(.light)
                dismiss()
            }) {
                Text("Leave round")
                    .font(.dmSans(size: 17, weight: .medium))
                    .foregroundColor(Color.systemError)
                    .alignLeading()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
        }
        .environmentObject(appSession)
        .padding(.vertical, 10)
        .background(Color.systemViewBackground)
        .onAppear() {
            maxScore = deviceDefaults.maxScoreOverPar
            hapticsEnabled = deviceDefaults.hapticsEnabled
            pushNotificationsEnabled = deviceDefaults.pushNotificationsEnabled
        }
        .onChange(of: maxScore, perform: { v in deviceDefaults.maxScoreOverPar = v })
        .onChange(of: hapticsEnabled, perform: { v in deviceDefaults.hapticsEnabled = v })
        .onChange(of: pushNotificationsEnabled, perform: { v in deviceDefaults.pushNotificationsEnabled = v })
        .sheet(isPresented: $showTerms) {
            TermsView(onAccept: {})
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExpirationInfo) {
            RoundExpirationView()
                .presentationDetents([.height(160)])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showPartyCode) {
            PartyCodeView(viewModel: viewModel)
        }
    }
    
    private var rows: some View {
        VStack(spacing: 24) {
            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    AwesomeImage(rawIcon: "e31b".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    Text("Party code")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
                    Button(action: {
                        showPartyCode = true
                        Haptics.fire(.light)
                    }) {
                        if viewModel.partyCode.isEmpty {
                            Text("Set party code")
                                .foregroundColor(Color.systemBlack)
                                .font(.dmSans(size: 13, weight: .bold))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(colorScheme.superlightGray)
                                .cornerRadius(4)
                        } else {
                            Text(viewModel.partyCode)
                                .foregroundColor(Color.systemHackersGreen)
                                .font(.dmSans(size: 13, weight: .bold))
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(Color.systemHackersGreen.opacity(colorScheme.translucent))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            Button(action: {
                print("todo: show sheet for spectating another party w/ spectate code")
                Haptics.fire(.light)
            }) {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        AwesomeImage(rawIcon: "e03e".unicode, style: .regular, size: 17, color: .systemBlack)
                            .frame(width: 22)
                        Text("Spectate")
                            .font(.dmSans(size: 17, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                        
                        Spacer(minLength: 0)
                        
                        Text("Coming soon")
                            .foregroundColor(Color.systemHackersYellow)
                            .font(.dmSans(size: 13, weight: .bold))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Color.systemHackersYellow.opacity(colorScheme.translucent))
                            .cornerRadius(4)
                        
//                        AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                    }
                }
//                .padding(.vertical, 10)
            }
            
            VStack(spacing: 4) {
                HStack(spacing: 16) {
                    AwesomeImage(rawIcon: "e3ac".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    Text("Score limit")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
                    Menu {
                        Button(action: {
                            maxScore = 3
                            Haptics.fire(.light)
                        }) {
                            Text(PlayerScore.triple.menuName)
                        }
                        Button(action: {
                            maxScore = 4
                            Haptics.fire(.light)
                        }) {
                            Text(PlayerScore.quad.menuName)
                        }
                        Button(action: {
                            maxScore = 5
                            Haptics.fire(.light)
                        }) {
                            Text(PlayerScore.quin.menuName)
                        }
                        Button(action: {
                            maxScore = 6
                            Haptics.fire(.light)
                        }) {
                            Text(PlayerScore.sex.menuName)
                        }
                    } label: {
                        Text("\(maxScore) over par")
                            .font(.dmSans(size: 15, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(colorScheme.superlightGray)
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                    .onTapGesture {
                        Haptics.fire(.light)
                    }
                }
            }
            
            Toggle(isOn: $hapticsEnabled, label: {
                HStack(spacing: 16) {
                    AwesomeImage(rawIcon: "e1a2".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    Text("Haptics")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                }
            })
            .tint(Color.systemHackersGreen)
            
            Toggle(isOn: $pushNotificationsEnabled, label: {
                HStack(spacing: 16) {
                    AwesomeImage(rawIcon: "e1f0".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    Text("Push notifications")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                }
            })
            .tint(Color.systemHackersGreen)
            
            Button(action: {
                print("todo: show sheet for feedback for phone # and send button with status as suggestion")
                Haptics.fire(.light)
            }) {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        AwesomeImage(rawIcon: "f735".unicode, style: .regular, size: 17, color: .systemBlack)
                            .frame(width: 22)
                        Text("Suggestion box")
                            .font(.dmSans(size: 17, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                        
                        Spacer(minLength: 0)
                        
                        AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                    }
                }
                .padding(.top, 4)
            }
            
            Button(action: {
                AppStoreReviewManager.writeReview()
                Haptics.fire(.light)
            }) {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        AwesomeImage(rawIcon: "f005".unicode, style: .regular, size: 17, color: .systemBlack)
                            .frame(width: 22)
                        Text("Write a review")
                            .font(.dmSans(size: 17, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                        
                        Spacer(minLength: 0)
                        
                        AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                    }
                }
                .padding(.top, 4)
            }
            
            Button(action: {
                showTerms = true
                Haptics.fire(.light)
            }) {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        AwesomeImage(rawIcon: "f24e".unicode, style: .regular, size: 17, color: .systemBlack)
                        Text("Terms")
                            .font(.dmSans(size: 17, weight: .regular))
                            .foregroundColor(Color.systemBlack)
                        
                        Spacer(minLength: 0)
                        
                        AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var hackersPro: some View {
        Button(action: {
            print("todo: show view for managing Hackers PRO")
            Haptics.fire(.light)
        }) {
            HStack(spacing: 20) {
                Image(uiImage: Asset.Images.logoPro.image)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 8)
                
                Group {
                    Text("Start a trial or purchase now to ")
                        .foregroundColor(Color.systemBlack)
                        .font(.dmSans(size: 15, weight: .regular))
                    + Text("unlock and play all sides games.")
                        .foregroundColor(Color.systemHackersPurple)
                        .font(.dmSans(size: 15, weight: .bold))
                }
                .multilineTextAlignment(.leading)
                .alignLeading()
                .alignTop()
            }
            .padding(20)
            .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
    }
}

struct ManageRoundView_Previews: PreviewProvider {
    static var appSession = AppSession()
    static var previews: some View {
        ManageRoundView(viewModel: RoundViewModel())
            .environmentObject(appSession)
            .onAppear() {
                appSession.session = Session()
            }
            .holisticPreview()
    }
}
