//
//  PrivacyPolicyView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
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
                .fontStyle(size: 18, weight: .medium)
                .foregroundColor(Color.foregroundPrimary)
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
                        .stroke(Color.neutral5, lineWidth: 2)
                        .frame(width: 80, height: 80)
                    
                    Icon(name: "f24e", size: 32, maxSize: 32, weight: .regular)
                        .foregroundStyle(Color.foregroundPrimary)
                }
                
                VStack(spacing: 4) {
                    Text("\(hasPreviouslyAccepted ? "Updated Policy" : "Privacy Policy")")
                        .fontStyle(size: 20, weight: .semibold)
                        .foregroundColor(Color.foregroundPrimary)
                    
                    Text("\(Date().formatted(date: .long, time: .omitted))")
                        .fontStyle(size: 15)
                        .foregroundColor(Color.neutral)
                }
                
                Text(.init(kPrivacyPolicy))
                    .fontStyle(size: 13)
                    .foregroundColor(Color.foregroundPrimary)
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
}

#Preview {
    PrivacyPolicyView()
        .environmentObject(AppSession())
}
