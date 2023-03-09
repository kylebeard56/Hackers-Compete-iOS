//
//  TermsView.swift
//  Hackers
//
//  Created by Kyle Beard on 3/8/23.
//

import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) var dismiss
    var onAccept: () -> Void
    
    var body: some View {
        VStack (spacing: 16) {
            ZStack {
                Text("\(deviceDefaults.acceptedTerms ? "Updated Terms" : "Terms of Service")")
                    .font(.dmSans(size: 20, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .padding(.top, 16)
                
                if deviceDefaults.acceptedTerms {
                    BackButton(icon: .xmark, style: .solid, onTap: { dismiss() })
                        .alignTrailing()
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 16)
            
            ScrollView {
                text
                    .font(.dmSans(size: 15))
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
    }
    
    private var text: some View {
        Text(
"""
**Welcome to Hackers!**
These Terms of Service ("Terms") apply to your use of our application (the "App"). By downloading or using the App, you agree to these Terms. If you do not agree with these Terms, you should not use the App.

**License Grant**
Hackers grants you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial use only. The license is subject to these Terms and our Privacy Policy.

**Use of the App**
You agree to use the App only for its intended purposes, which includes playing in the card game, use of round scoring, and sharing or joining of a round to synchronize session with your party - of which consent to share or join the round was mutually agreed upon prior to action in the App. You may not use the App for any illegal or unauthorized purpose. You agree to comply with all applicable laws, rules, and regulations when using the App.

**User Accounts**
You do not need to create an account to use the App. If you choose to create an account, you will be asked to provide some personal information. We will only use this information to provide you with the services of the App and will not share it with any third parties.

**Anonymous Data Collection**
The App collects analytical data about how users interact with the App. This data is collected anonymously and only includes personally identifiable information to the extent of which information is optionally provided to the App by you, the user. We use this data to improve the App and provide a better user experience.

**Intellectual Property**
The App and all content and materials contained in the App, including but not limited to graphics, text, logos, images, and software, are the property of Hackers or its licensors and are protected by copyright and other intellectual property laws. You may not modify, copy, reproduce, distribute, or create derivative works based on the App or any content or materials contained in the App.

**Disclaimers**
The App is provided on an "as-is" basis without any warranties, express or implied. Hackers does not warrant that the App will be error-free, uninterrupted, or free from viruses or other harmful components.

**Limitation of Liability**
Hackers will not be liable for any damages arising from your use of the App, including but not limited to direct, indirect, incidental, punitive, and consequential damages.

**Indemnification**
You agree to indemnify and hold Hackers, its officers, directors, employees, and agents harmless from any claim, demand, or damage, including reasonable attorneys' fees, arising out of or related to your use of the App or your breach of these Terms.

**Changes to these Terms**
Hackers may update these Terms from time to time. We will notify you of any material changes by posting a notice on the App or by email. Your continued use of the App after any changes to these Terms will constitute your acceptance of the changes.

**Governing Law**
These Terms and your use of the App are governed by the laws of the United States of America ("USA") without regard to its conflict of law provisions.

**Dispute Resolution**
Any dispute arising out of or related to these Terms or your use of the App will be resolved through binding arbitration in accordance with the rules of the American Arbitration Association. The arbitration will be conducted in Greenville, South Carolina, USA.

**Entire Agreement**
These Terms constitute the entire agreement between you and Hackers regarding the use of the App and supersede all prior or contemporaneous communications and proposals, whether oral or written, between you and Hackers.

If you have any questions about these Terms or the App, please contact kyle@tigermindlabs.com.
"""
        )
    }
}

struct TermsView_Previews: PreviewProvider {
    static var previews: some View {
        TermsView(onAccept: {})
    }
}
