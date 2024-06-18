//
//  PurchaseView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import StoreKit
import SwiftUI

struct PurchaseView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var purchaseStore: PurchaseStore
    
    @State private var selectedOption: HackersPro = .yearly
    @State private var showTerms: Bool = false
    @State private var showVIPCode: Bool = false
    
    var allowSkip: Bool = false
    var onSuccess: OnTap?
    var onSkip: OnTap?
    
    private var primaryButtonLabel: String {
        if self.selectedOption == .yearly && purchaseStore.isTrailAvailable {
            return "Redeem free trial"
        } else {
            return "Continue"
        }
    }
    
    private var subtitleLabel: String {
        if purchaseStore.isTrailAvailable {
            return "Start your trial or purchase now to "
        } else {
            return "Purchase now to "
        }
    }
    
    private var buttonWidth: CGFloat {
        (UIScreen.main.bounds.width - 40) / 2
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Get Hackers Pro")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 20, weight: .bold)
                
                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
                    .padding(.trailing, 20)
            }
            .padding(.vertical, 10)
            
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .alignTop()
            }

            VStack(spacing: 20) {
                Divider()
                
                if allowSkip {
                    SmallButton(title: "I don't want to play a side game", isDisabled: .false, isLoading: .false)
                        .onTap {
                            triggerOnSkip()
                            dismiss()
                        }
                        .padding(.horizontal, 20)
                }
                
                BigButton(
                    title: primaryButtonLabel,
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersPurple,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTapAsync {
                    await purchaseStore.purchase(selectedOption)
                }
                .padding(.horizontal, 20)
            }
        }
        .environmentObject(purchaseStore)
        .background(Color.systemViewBackground)
        .onReceive(purchaseStore.$didCompletePurchase, perform: { value in
            if value {
                purchaseStore.didCompletePurchase = false
                triggerOnSuccess()
            }
        })
        .sheet(isPresented: $showTerms) {
            TermsView(title: "Terms of Service", onAccept: {})
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showVIPCode, onDismiss: {
            if deviceDefaults.isLifetimeUnlocked { dismiss() }
        }) {
            VIPCodeEntryView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Image(uiImage: Asset.Images.logoPro.image)
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(height: 100)
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 8)
                .padding(.vertical, 10)
            
            Group {
                Text(subtitleLabel)
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
                + Text("**unlock all side games for your party.**")
                    .foregroundColor(Color.systemHackersPurple)
                    //.font(.dmSans, size: 17, weight: .bold)
            }
            .font(.dmSans, size: 17)
            .alignLeading()
            
            if deviceDefaults.isEarlyBirdUser {
                earlyBirdTile
            }
            
            ForEach([HackersPro.yearly, HackersPro.monthly, HackersPro.lifetime], id: \.self) { plan in
                if let product = purchaseStore.products.first(where: { $0.id == plan.productID }) {
                    tile(product: product, plan: plan)
                }
            }
            
            Circle()
                .fill(Color.systemGray5)
                .frame(width: 8, height: 8)
            Circle()
                .fill(Color.systemGray5)
                .frame(width: 8, height: 8)
//            Circle()
//                .fill(Color.systemGray5)
//                .frame(width: 8, height: 8)
            
            pricePerspective
            
            SmallButton(title: "Redeem promo code", isDisabled: .false, isLoading: .false)
                .onTap {
                    showVIPCode = true
                }
            
            restoreTermsView
             
            Spacer(minLength: 60)
        }
    }
    
    private var pricePerspective: some View {
        VStack(spacing: 20) {
            Group {
                Text("How does ")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
                + Text("**Hackers Pro**")
                    .foregroundColor(Color.systemHackersPurple)
                    //.font(.dmSans, size: 17, weight: .bold)
                + Text(" stack up against common golf expenses?")
                    .foregroundColor(Color.systemBlack)
                    //.font(.dmSans, size: 17, weight: .regular)
            }
            .font(.dmSans, size: 17)
            .alignLeading()
        
            VStack(spacing: 8) {
                Group {
                    row(title: "Hackers Pro Monthly", value: "$1", highlight: true)
                    row(title: "Lost ball", value: "$4")
                    row(title: "Hot dog at the turn", value: "$5")
                    row(title: "Beer from the cart girl", value: "$6")
                }
                Group {
                    row(title: "Hackers Pro Yearly", value: "$10", highlight: true)
                    row(title: "Transfusion at the turn", value: "$12")
                    row(title: "New bag of tees", value: "$15")
                    row(title: "New glove", value: "$20")
                }
                Group {
                    row(title: "Hackers Pro Lifetime", value: "$25", highlight: true)
                    row(title: "18 holes + cart fee", value: "$36")
                    row(title: "Dozen balls", value: "$50")
                    row(title: "New polo", value: "$60")
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 16)
            .border(
                colorScheme.isLight ? Color.systemGray6 : Color.systemGray4,
                width: 2,
                cornerRadius: 12
            )
        }
    }
    
    // MARK: - Reusable components
    
    @ViewBuilder private func row(title: String, value: String, highlight: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.dmSans, size: 15, weight: highlight ? .bold : .medium)
                .foregroundColor(highlight ? Color.systemHackersPurple : Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
            
            Text(value)
                .font(.dmSans, size: 15, weight: highlight ? .bold : .medium)
                .foregroundColor(highlight ? Color.systemHackersPurple : Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.systemHackersPurple.opacity(highlight ? colorScheme.translucent : 0))
        .cornerRadius(8)
    }
    
    @ViewBuilder private var earlyBirdTile: some View {
        Button(action: {
            purchaseStore.presentPromoCode(for: "EARLYBIRD")
            Haptics.fire(.light)
        }) {
            VStack(spacing: 8) {
                Text("You're awesome.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 20, weight: .bold)
                    .lineLimit(1)
                    .alignLeading()
                
                Group {
                    Text("As a huge thank you for supporting us in our early stages, use code ")
                        .foregroundColor(Color.systemGray)
                        //.font(.dmSans, size: 15, weight: .regular)
                    + Text("**EARLYBIRD**")
                        .foregroundColor(Color.systemHackersPurple)
                        //.font(.dmSans, size: 15, weight: .bold)
                    + Text(" to get **6 months free** of Hackers Pro.")
                        .foregroundColor(Color.systemGray)
                        //.font(.dmSans, size: 15, weight: .regular)
                }
                .font(.dmSans, size: 17)
                .multilineTextAlignment(.leading)
                .alignLeading()
                
                Text("Redeem now")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 15, weight: .bold)
                    .alignTrailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemGray6)
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder private func tile(product: Product, plan: HackersPro) -> some View {
        let isSelected: Bool = self.selectedOption == plan
        let canTrial: Bool = purchaseStore.isTrailAvailable && plan == .yearly
        Button(action: {
            self.selectedOption = plan
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.systemHackersPurple.opacity(colorScheme.translucent) : Color.systemGray6)
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: isSelected ? "f00c".unicode : plan.icon.unicode,
                        style: .regular,
                        size: 24,
                        color: isSelected ? Color.systemHackersPurple : Color.systemBlack
                    )
                }
                
                VStack(spacing: 2) {
                    HStack {
                        Text("\(product.displayPrice)\(plan.title)")
                            .foregroundColor(isSelected ? Color.systemHackersPurple : Color.systemBlack)
                            .font(.dmSans, size: 20, weight: .bold)
                            .lineLimit(1)
                        
                        Spacer(minLength: 0)
                        
                        if canTrial {
                            Text("Free trial")
                                .foregroundColor(Color.systemHackersPurple)
                                .font(.dmSans, size: 13, weight: .bold)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 6)
                                .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
                                .cornerRadius(4)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    
                    Text(canTrial ?  "after a 14 day trial" : plan.subtitle)
                        .foregroundColor(Color.systemGray)
                        .font(.dmSans, size: 15, weight: .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignLeading()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                isSelected ? Color.systemHackersPurple : colorScheme.lightGray,
                width: isSelected ? 6 : 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder private var restoreTermsView: some View {
        HStack(spacing: 0) {
            Button(action: {
                Task(operation: purchaseStore.restorePurchases)
                Haptics.fire(.light)
            }) {
                Text("Restore purchases")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 15, weight: .medium)
            }
            .frame(width: buttonWidth)
            
            Button(action: {
                showTerms = true
                Haptics.fire(.light)
            }) {
                Text("Terms of Service")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans, size: 15, weight: .medium)
            }
            .frame(width: buttonWidth)
        }
    }
}

extension PurchaseView {
    
    // MARK: - OnSuccess
    
    func triggerOnSuccess() {
        if let action = onSuccess {
            action()
        }
    }
    
    func onSuccess(perform action: @escaping () -> Void) -> Self {
        var a = self
        a.onSuccess = action
        return a
    }
    
    // MARK: - OnSkip
    
    func triggerOnSkip() {
        if let action = onSkip {
            action()
        }
    }
    
    func onSkip(perform action: @escaping () -> Void) -> Self {
        var a = self
        a.onSkip = action
        return a
    }
}

#Preview("Light") {
    PurchaseView(allowSkip: true)
        .environmentObject(PurchaseStore())
        .lightModePreview()
}

#Preview("Dark") {
    PurchaseView(allowSkip: true)
        .environmentObject(PurchaseStore())
        .darkModePreview()
}
