//
//  TermsView.swift
//  Hackers
//
//  Created by Kyle Beard on 3/8/23.
//

import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) var dismiss
    
    var title: String?
    var onAccept: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    if let title {
                        Text(title)
                            .font(.dmSans, size: 20, weight: .bold)
                            .foregroundColor(Color.systemBlack)
                            .padding(.top, 16)
                    } else {
                        Text("\(deviceDefaults.acceptedTerms ? "Updated Terms" : "Terms of Service")")
                            .font(.dmSans, size: 20, weight: .bold)
                            .foregroundColor(Color.systemBlack)
                            .padding(.top, 16)
                    }

                    if deviceDefaults.acceptedTerms {
                        BackButton(icon: .xmark, style: .solid, onTap: { dismiss() })
                            .alignTrailing()
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 16)
                
                ScrollView {
                    Text("\(Date().formatted(date: .long, time: .omitted))")
                        .font(.dmSans, size: 15, weight: .medium)
                        .foregroundColor(Color.systemGray)
                        .padding(.horizontal, 16)
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                        .padding(.bottom, 8)
                    
                    text
                        .font(.dmSans, size: 15)
                        .foregroundColor(Color.systemBlack)
                        .padding(.horizontal, 16)
                        .multilineTextAlignment(.leading)
                        .alignLeading()
                }
                
                if !deviceDefaults.acceptedTerms {
                    BigButton(
                        title: "Accept",
                        labelColor: .systemWhite,
                        buttonColor: .systemBlack,
                        isDisabled: .false, isLoading: .false, onTap: onAccept)
                        .padding(.horizontal, 16)
                }
            }
            .background(Color.systemViewBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private var text: some View {
        Text(
"""
**Welcome to Hackers!**
These Terms of Service ("Terms") apply to your use of our application (the "App"). By downloading and using the App, you acknowledge that you have read, understood, and agree to these Terms.

**License Grant**
Hackers grants you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial use only. The license is subject to these Terms and our Privacy Policy.

**Use of the App**
You agree to use the App only for its intended purposes, which includes creating and configuring golf rounds, use of leaderboard or game play, and sharing or joining of a round to synchronize session with your party - of which consent to share or join the round was mutually agreed upon prior to action in the App. You may not use the App for any illegal or unauthorized purpose. You will not engage in any activities that could harm the security, integrity, or availability of the App or its users.

**Subscriptions and Purchases**
Hackers offers In-App Purchases ("Purchases") that are one-time charges or auto-renewing charges ("Subscriptions") for unlocking content. Subscriptions may be available in varying durations (i.e. yearly, monthly) and may contain trial periods before any charges are incurred. Prior to trial, Purchases, or Subscriptions, you agree that you are 18 years of age or older, or have permission to make Purchases or Subscriptions from a parent or legal guardian. You are responsible for the management and cancellation of any Purchases, Subscriptions, or offer codes that are subject to auto-renewal. All payments for Purchases or Subscriptions will be processed through the Apple App Store. You agree to pay all charges associated with your selected Purchases or Subscriptions, include applicable tax. You can manage your Purchases or Subscriptions and cancel auto-renewal through your Apple ID settings. Changes or cancellations will take effect at the end of the current billing period.

**Right of Refund**
You agree to comply with all applicable laws, rules, and regulations when using the App and making Purchases. Hackers reserves the right to suspend or deny any user without cause or suspicion and will not be held responsible for refunds for any reason. Hackers reserves right of refund - all sales are considered final.

**User Accounts**
You do not need to create an account to use the App. If you choose to create an account, you will be asked to provide some personal information. We will only use this information to provide you with the services of the App and will not share it with any third parties.

**Anonymous Data Collection**
The App collects analytical data about how users interact with the App. This data is collected anonymously and only includes personally identifiable information to the extent of which information is optionally provided to the App by you, the user. We use this data to improve the App and provide a better user experience.

**Intellectual Property**
The App and all content and materials contained in the App, including but not limited to graphics, text, logos, images, and software, are the property of Hackers or its licensors and are protected by copyright and other intellectual property laws. You may not modify, copy, reproduce, distribute, or create derivative works based on the App or any content or materials contained in the App.

**Disclaimers**
The App is provided on an "as-is" basis without any warranties, express or implied. Hackers does not warrant that the App will be error-free, uninterrupted, or free from viruses or other harmful components.

**Limitation of Liability**
Hackers will not be liable for any damages arising from your use of or connection to the App, including but not limited to direct, indirect, incidental, punitive, and consequential damages.

**Indemnification**
You agree to indemnify and hold Hackers, its officers, directors, employees, and agents harmless from any claim, demand, or damage, including reasonable attorneys' fees, arising out of or related to your use of the App or your breach of these Terms.

**Changes to these Terms**
Hackers may update these Terms from time to time. We will notify you of any material changes by posting a notice on the App or by email. Your continued use of the App after any changes to these Terms will constitute your acceptance of the changes.

**Governing Law**
These Terms and your use of the App are governed by the laws of the United States of America ("USA") without regard to its conflict of law provisions.

**Dispute Resolution**
Any dispute arising out of or related to these Terms or your use of the App will be resolved through binding arbitration in accordance with the rules of the American Arbitration Association. The arbitration will be conducted in Greenville, South Carolina, USA.

**Entire Agreement**
These Terms constitute the entire agreement between you and Hackers regarding the use of the App and supersede all prior or contemporaneous communications and proposals, whether oral or written, between you and Hackers. By using the App, you agree to abide by these Terms.

If you have any questions about these Terms or the App, please contact our staff at editors@tigermindlabs.com.
"""
        )
    }
}

struct TermsView_Previews: PreviewProvider {
    static var previews: some View {
        TermsView(onAccept: {})
    }
}
