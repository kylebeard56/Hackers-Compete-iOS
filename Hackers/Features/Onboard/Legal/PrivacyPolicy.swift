//
//  PrivacyPolicy.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

struct PrivacyPolicy: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession

    @State private var hasPreviouslyAccepted = false
    @State private var animateNavTitle = false
    
    var body: some View {
        StickyScrollView(
            header: { headerContent },
            content: { scrollableContent },
            footer: { EmptyView() },
            onScroll: { offset in await onScroll(offset) }
        )
        .navigationBarBackButtonHidden(true)
        .task {
            hasPreviouslyAccepted = await AppData.shared.user?.legal.privacyPolicy.isPopulated ?? false
        }
    }
    
    private var headerContent: some View {
        ZStack {
            Text("\(hasPreviouslyAccepted ? "Updated Policy" : "Privacy Policy")")
                .font(.system(size: 18, weight: .medium, design: kFontDesign))
                .foregroundColor(Color.hackersForeground)
                .opacity(animateNavTitle ? 1 : 0)
                .offset(y: animateNavTitle ? 0 : 10)
            
            NavButton(onTap: { dismiss() })
                .alignTrailing()
                .padding(.horizontal, 16)
        }
    }
    
    private var scrollableContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.hackersGray5, lineWidth: 2)
                        .frame(width: 80, height: 80)
                    
                    Icon(name: "f24e", size: 32, maxSize: 32, weight: .regular)
                        .foregroundStyle(Color.hackersForeground)
                }
                
                VStack(spacing: 4) {
                    Text("\(hasPreviouslyAccepted ? "Updated Policy" : "Privacy Policy")")
                        .font(.system(size: 20, weight: .semibold, design: kFontDesign))
                        .foregroundColor(Color.hackersForeground)
                    
                    Text("\(Date().formatted(date: .long, time: .omitted))")
                        .font(.system(size: 15, weight: .regular, design: kFontDesign))
                        .foregroundColor(Color.hackersGray)
                }
                
                text
                    .font(.system(size: 15, design: kFontDesign))
                    .foregroundColor(Color.hackersForeground)
                    .lineSpacing(2)
                    .padding(.horizontal, 16)
                    .multilineTextAlignment(.leading)
                    .alignLeading()
                
                Spacer(minLength: 0)
                    .frame(height: 16)
            }
        }
    }
    
    @MainActor
    private func onScroll(_ value: CGFloat) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            animateNavTitle = value < -120
        }
    }
    
    private var text: some View {
        Text("""
Hackers Golf ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our iOS application ("App"). Please read this privacy policy carefully. If you do not agree with the terms of this privacy policy, please do not access the App.

**1. Information We Collect**
We only collect anonymous data to improve the App’s performance and your experience. The data collected cannot be used to identify you personally. The types of anonymous data we collect include:

- Usage Data: Information about how you use the App, including the screens you visit, the time spent on each screen, and the actions you take within the App.

- Device Information: Information about the device you use to access the App, such as device type, operating system, and unique device identifiers.

**2. Use of Your Information**
We use the information we collect to:

- Monitor and analyze usage and trends to improve the user experience.

- Diagnose and fix technology problems.

- Update and enhance the App’s performance and features.

**3. Disclosure of Your Information**
We do not share, sell, or otherwise disclose your information to third parties, except in the following circumstances:

- Service Providers: We may share information with third-party service providers who perform services for us or on our behalf, such as analytics providers, to help us analyze how users use the App.

- Legal Requirements: We may disclose your information if required to do so by law or in response to valid requests by public authorities (e.g., a court or a government agency).

**4. Security of Your Information**
We use administrative, technical, and physical security measures to help protect your anonymous data. While we have taken reasonable steps to secure the data you provide to us, please be aware that despite our efforts, no security measures are perfect or impenetrable, and no method of data transmission can be guaranteed against any interception or other type of misuse.

**5. Changes to This Privacy Policy**
We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy within the App. You are advised to review this Privacy Policy periodically to stay informed of updates. Your continued use of the App after any changes to this Privacy Policy will constitute your acknowledgment of the changes and your consent to abide and be bound by the updated Privacy Policy.

**6. Contact Us**
If you have any questions or concerns about this Privacy Policy, please contact us at editors@tigermindlabs.com

**By using Hackers Golf, you agree to the terms of this Privacy Policy.**
""")
    }
}

#Preview {
    PrivacyPolicy()
        .environmentObject(AppSession())
}
