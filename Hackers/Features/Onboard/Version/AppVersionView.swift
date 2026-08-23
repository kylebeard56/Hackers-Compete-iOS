//
//  AppVersionView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import SwiftUI

struct AppVersionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            
            Logo()
                .frame(width: UIScreen.main.bounds.width * 0.69)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 0)
            
            Text("A newer version is available")
                .fontStyle(weight: .bold)
                .foregroundStyle(Color.foregroundPrimary)
            
            Spacer(minLength: 0)
            
            downloadButton
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 0)
        }
        .padding(16)
        .background(GolfTopology())
        .navigationBarBackButtonHidden(true)
    }
    
    private var downloadButton: some View {
        PrimaryButton(
            appearance: .fill,
            title: "Download now",
            labelColor: .backgroundPrimary,
            buttonColor: .foregroundPrimary,
            iconSize: 24,
            isDisabled: .false,
            isLoading: .false,
            onTap: openAppStore
        )
    }
    
    private func openAppStore() {
        if let url = URL(string: kAppStoreLink) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    AppVersionView()
}
