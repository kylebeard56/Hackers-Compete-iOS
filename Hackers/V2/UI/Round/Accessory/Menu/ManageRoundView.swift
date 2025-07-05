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
    @EnvironmentObject var purchaseStore: PurchaseStore
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var showIAP: Bool = false
    @State private var showHackersProManage: Bool = false
    @State private var showPartyCode: Bool = false
    @State private var showSpectate: Bool = false
    @State private var showRuleEditor: Bool = false
    @State private var hapticsEnabled: Bool = false
    @State private var pushNotificationsEnabled: Bool = false
    @State private var showSuggestionBox: Bool = false
    @State private var showTerms: Bool = false
    @State private var showExpirationInfo: Bool = false
    @State private var showVIPCode: Bool = false
    
    private var isExpired: Bool {
        roundSession.session?.isExpired ?? true
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Settings")
                    .font(.dmSans, size: 28, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        if let plan = HackersPro.allCases.first(where: {
                            $0.productID == purchaseStore.currentProPlan?.productID ?? ""
                        }) {
                            hackersProPlan(for: plan)
                        } else if deviceDefaults.isLifetimeUnlocked {
                            hackersProPlan(for: .lifetime)
                        } else {
                            purchaseHackersPro
                        }
                    }
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
                    .font(.dmSans, size: 17, weight: .medium)
                    .foregroundColor(Color.systemError)
                    .alignLeading()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
        }
        .environmentObject(appSession)
        .environmentObject(purchaseStore)
        .environmentObject(roundSession)
        .padding(.vertical, 10)
        .background(Color.systemViewBackground)
        .onAppear() {
//            maxScore = deviceDefaults.maxScoreOverPar
            hapticsEnabled = deviceDefaults.hapticsEnabled
            pushNotificationsEnabled = deviceDefaults.pushNotificationsEnabled
        }
//        .onChange(of: maxScore, perform: { v in deviceDefaults.maxScoreOverPar = v })
        .onChange(of: hapticsEnabled, perform: { v in deviceDefaults.hapticsEnabled = v })
        .onChange(of: pushNotificationsEnabled, perform: { v in deviceDefaults.pushNotificationsEnabled = v })
        .onReceive(purchaseStore.$didCompletePurchase, perform: { value in
            if value {
                showIAP = false
            }
        })
        .sheet(isPresented: $showTerms) {
            TermsView(title: "Terms of Service", onAccept: {})
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExpirationInfo) {
            RoundExpirationView()
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showIAP) {
            PurchaseView()
        }
        .fullScreenCover(isPresented: $showRuleEditor) {
            ChaosRuleViewer()
        }
        .sheet(isPresented: $showSuggestionBox) {
            SuggestionBoxView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHackersProManage) {
            subscriptionInfoCard
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showPartyCode) {
            PartyCodeView()
        }
        .fullScreenCover(isPresented: $showSpectate) {
            SpectateView()
        }
        .sheet(isPresented: $showVIPCode) {
            VIPCodeEntryView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    @ViewBuilder private var subscriptionInfoCard: some View {
        if deviceDefaults.isLifetimeUnlocked {
            InfoCard(
                title: "Hackers Pro Membership",
                subtitle: "You've redeemed a promo code for a lifetime of free Hackers Pro, which means you are awesome and we very much appreciate your support on this journey.",
                buttonText: "Dismiss",
                color: Color.systemHackersPurple
            )
            .onTap {
                showHackersProManage = false
            }
        } else {
            InfoCard(
                title: "Hackers Pro Membership",
                subtitle: "You've purchased Hackers Pro, which helps support future features and gives you access to all side games.\n\nTo manage your subscription, go to Settings > Account > Subscriptions and find the active Hackers plan.",
                buttonText: "Go to Settings",
                color: Color.systemHackersPurple
            )
            .onTap {
                if let appSettings = URL(string: UIApplication.openSettingsURLString + Bundle.main.bundleIdentifier!) {
                    if UIApplication.shared.canOpenURL(appSettings) {
                        DispatchQueue.main.async {
                            UIApplication.shared.open(appSettings)
                        }
                    }
                }
            }
        }
    }
    
    private var rows: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                AwesomeImage(rawIcon: "e31b".unicode, style: .regular, size: 17, color: .systemBlack)
                    .frame(width: 22)
                Text("Party code")
                    .font(.dmSans, size: 17, weight: .regular)
                    .foregroundColor(Color.systemBlack)
                
                Spacer(minLength: 0)
                
                Button(action: {
                    showPartyCode = true
                    Haptics.fire(.light)
                }) {
                    ChipButton(
                        text: roundSession.partyCode.isEmpty ? "Not set" : roundSession.partyCode,
                        foregroundColor: roundSession.partyCode.isEmpty ? Color.systemGray : Color.systemBlack,
                        backgroundColor: colorScheme.superlightGray
                    )
                }
            }
            
            Button(action: {
                showSpectate = true
                Haptics.fire(.light)
            }) {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        AwesomeImage(rawIcon: "e03e".unicode, style: .regular, size: 17, color: .systemBlack)
                            .frame(width: 22)
                        Text("Spectate")
                            .font(.dmSans, size: 17, weight: .regular)
                            .foregroundColor(Color.systemBlack)
                        
                        Spacer(minLength: 0)
                        
                        AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                        
                    }
                }
            }
            
            if appConfig.environment == .admin {
                Button(action: {
                    showRuleEditor = true
                    Haptics.fire(.light)
                }) {
                    VStack(spacing: 10) {
                        HStack(spacing: 16) {
                            AwesomeImage(rawIcon: "f303".unicode, style: .regular, size: 17, color: .systemBlack)
                                .frame(width: 22)
                            Text("Cards of Chaos rules")
                                .font(.dmSans, size: 17, weight: .regular)
                                .foregroundColor(Color.systemBlack)
                            
                            Spacer(minLength: 0)
                            
                            AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                        }
                    }
                }
            }
            
//            Toggle(isOn: $pushNotificationsEnabled, label: {
//                HStack(spacing: 16) {
//                    AwesomeImage(rawIcon: "e1f0".unicode, style: .regular, size: 17, color: .systemBlack)
//                        .frame(width: 22)
//                    Text("Push notifications")
//                        .font(.dmSans, size: 17, weight: .regular)
//                        .foregroundColor(Color.systemBlack)
//                    Spacer(minLength: 0)
//                }
//            })
//            .tint(Color.systemHackersGreen)
            
            if !deviceDefaults.isLifetimeUnlocked {
                Button(action: {
                    showVIPCode = true
                    Haptics.fire(.light)
                }) {
                    VStack(spacing: 10) {
                        HStack(spacing: 16) {
                            AwesomeImage(rawIcon: "f543".unicode, style: .regular, size: 17, color: .systemBlack)
                                .frame(width: 22)
                            Text("Redeem promo code")
                                .font(.dmSans, size: 17, weight: .regular)
                                .foregroundColor(Color.systemBlack)
                            
                            Spacer(minLength: 0)
                            
                            AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Button(action: {
                showSuggestionBox = true
                Haptics.fire(.light)
            }) {
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        AwesomeImage(rawIcon: "f735".unicode, style: .regular, size: 17, color: .systemBlack)
                            .frame(width: 22)
                        Text("Suggestion box")
                            .font(.dmSans, size: 17, weight: .regular)
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
                            .font(.dmSans, size: 17, weight: .regular)
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
                        Text("Terms of Service")
                            .font(.dmSans, size: 17, weight: .regular)
                            .foregroundColor(Color.systemBlack)
                        
                        Spacer(minLength: 0)
                        
                        AwesomeImage(rawIcon: "f054".unicode, style: .regular, size: 17, color: .systemBlack)
                    }
                }
                .padding(.top, 4)
            }
            
            Toggle(isOn: $hapticsEnabled, label: {
                HStack(spacing: 16) {
                    AwesomeImage(rawIcon: "e1a2".unicode, style: .regular, size: 17, color: .systemBlack)
                        .frame(width: 22)
                    Text("Haptics")
                        .font(.dmSans, size: 17, weight: .regular)
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                }
            })
            .tint(Color.systemHackersGreen)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Subscription
    
    private var purchaseHackersPro: some View {
        Button(action: {
            showIAP = true
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
                    Text("Help support future features and ")
                        .foregroundColor(Color.systemBlack)
                        //.font(.dmSans, size: 15, weight: .regular)
                    + Text("**enjoy unlimited game play.**")
                        .foregroundColor(Color.systemHackersPurple)
                        //.font(.dmSans, size: 15, weight: .bold)
                }
                .font(.dmSans, size: 15)
                .multilineTextAlignment(.leading)
                .alignLeading()
                .alignTop()
            }
            .padding(20)
            .background(colorScheme.superlightGray)
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
    }
    
    private func hackersProPlan(for plan: HackersPro) -> some View {
        Button(action: {
            showHackersProManage = true
            Haptics.fire(.light)
        }) {
            
            HStack(spacing: 20) {
                Image(uiImage: Asset.Images.logoProWhite.image)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 8)
                
                VStack(spacing: 8) {
                    Text("Your current plan is")
                        .foregroundColor(Color.white)
                        .font(.dmSans, size: 15, weight: .bold)
                        .alignCenter()
                    
                    Text("🎉  \(plan.name.uppercased())  🎉")
                        .foregroundColor(Color.white)
                        .font(.dmSans, size: 22, weight: .bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignCenter()
                }
            }
            .padding(20)
            .background(Color.systemHackersPurple.opacity(colorScheme.isDark ? 0.69 : 1.0))
            .cornerRadius(20)
            .padding(.horizontal, 20)
        }
    }
}

struct ManageRoundView_Previews: PreviewProvider {
    static var appSession = AppSession()
    static var purchaseStore = PurchaseStore()
    static var roundSession = RoundSession()
    
    static var previews: some View {
        ManageRoundView()
            .environmentObject(appSession)
            .environmentObject(purchaseStore)
            .environmentObject(roundSession)
            .onAppear() {
                appSession.session = Session()
            }
            .holisticPreview()
    }
}
