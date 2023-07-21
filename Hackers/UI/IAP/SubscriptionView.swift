//
//  SubscriptionView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import SwiftUI

struct SubscriptionView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    @StateObject var viewModel = SubscriptionViewModel()
    
    private var primaryButtonLabel: String {
        if viewModel.isEligibleForTrial && viewModel.selectedOption == .yearly {
            return "Redeem free trial"
        } else {
            return "Continue"
        }
    }
    
    private var subtitleLabel: String {
        if viewModel.isEligibleForTrial {
            return "Start your trial or purchase now to "
        } else {
            return "Purchase now to "
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    ScrollViewReader { proxy in
                        content
                            .background(ScrollGeometry(name: "pro"))
                            .padding(.horizontal, 20)
                            .alignTop()
                    }
                }
                .coordinateSpace(name: "pro")
                .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in
                    print(v)
                })
                
                VStack(spacing: 20) {
                    Divider()
                    
                    Button(action: {
                        print("todo: restore purchases")
                        Haptics.fire(.light)
                    }) {
                        Text("Restore purchases")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 17, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    
                    BigButton(
                        title: primaryButtonLabel,
                        labelColor: .systemWhite,
                        buttonColor: .systemHackersPurple,
                        isDisabled: .false,
                        isLoading: $viewModel.isPurchasing
                    )
                    .onTap {
                        print("todo: attempt to purchase")
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 10)
            .navigationTitle("Get Hackers Pro")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 20, weight: .bold)]
            })
        }
        .environmentObject(appSession)
        .background(Color.systemViewBackground)
        .padding(.top, 10)
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
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("unlock all side games for your entire party.")
                    .foregroundColor(Color.systemHackersPurple)
                    .font(.dmSans(size: 17, weight: .bold))
            }
            .alignLeading()
            
            tile(for: .yearly)
            tile(for: .monthly)
            tile(for: .lifetime)
            
            Circle()
                .fill(Color.systemGray5)
                .frame(width: 8, height: 8)
            Circle()
                .fill(Color.systemGray5)
                .frame(width: 8, height: 8)
            Circle()
                .fill(Color.systemGray5)
                .frame(width: 8, height: 8)
            
            pricePerspective
             
            Spacer(minLength: 20)
            
            /// Here's how the Hackers plan fits into your golf budget:
            /// We show a rank of costs and interject the plans into the list
            /// Yearly
            ///    - Sleeve of ProV1s
            ///    - New glove
            /// Monthly
            ///    - A single ProV1
            ///    - Hot dog at the turn
            ///    - A single beer
            ///    - Bag of tees
            ///  Lifetime
            ///     - Cost of 18 holes
            ///     - Dozen ProV1s
        }
    }
    
    private var pricePerspective: some View {
        VStack(spacing: 20) {
            Group {
                Text("How does ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("Hackers Pro")
                    .foregroundColor(Color.systemHackersPurple)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" stack up against common golf expenses?")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .alignLeading()
        
            VStack(spacing: 4) {
                Group {
                    row(title: "Hackers Pro Monthly", value: "$3", highlight: true)
                    row(title: "Losing your ball", value: "$4")
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
                    row(title: "Hackers Pro Lifetime", value: "$50", highlight: true)
                    row(title: "Dozen balls", value: "$52")
                    row(title: "18 holes + cart fee", value: "$54")
                    row(title: "New polo", value: "$69")
//                    row(title: "New irons you don't need", value: "LOL")
                }
            }
            .padding(.vertical, 12)
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
                .font(.dmSans(size: 15, weight: highlight ? .bold : .medium))
                .foregroundColor(highlight ? Color.systemHackersPurple : Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer(minLength: 0)
            
            Text(value)
                .font(.dmSans(size: 15, weight: highlight ? .bold : .medium))
                .foregroundColor(highlight ? Color.systemHackersPurple : Color.systemBlack)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(Color.systemHackersPurple.opacity(highlight ? colorScheme.translucent : 0))
        .cornerRadius(8)
    }
    
    @ViewBuilder private func tile(for s: SubscriptionOption) -> some View {
        let isSelected: Bool = viewModel.selectedOption == s
        Button(action: {
            viewModel.selectedOption = s
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.systemHackersPurple.opacity(colorScheme.translucent) : Color.systemGray6)
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: isSelected ? "f00c".unicode : s.icon.unicode,
                        style: .regular,
                        size: 24,
                        color: isSelected ? Color.systemHackersPurple : Color.systemBlack
                    )
                }
                
                VStack(spacing: 4) {
                    Text(s.title)
                        .foregroundColor(isSelected ? Color.systemHackersPurple : Color.systemBlack)
                        .font(.dmSans(size: 20, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignLeading()
                    
                    Text(s.subtitle)
                        .foregroundColor(Color.systemGray)
                        .font(.dmSans(size: 15, weight: .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignLeading()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                isSelected ? Color.systemHackersPurple : colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
                width: isSelected ? 6 : 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
            .environmentObject(AppSession())
            .holisticPreview()
    }
}
