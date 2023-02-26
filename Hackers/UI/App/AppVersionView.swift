//
//  AppVersionView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/26/23.
//

import SwiftUI

struct AppVersionView: View {
    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("Good news")
                .font(.dmSans(size: 32, weight: .medium))
                .foregroundColor(Color.white)
                .alignCenter()
            
            Text("A newer version of Hackers is available.")
                .font(.dmSans(size: 17, weight: .regular))
                .foregroundColor(Color.white)
                .multilineTextAlignment(.center)
                .alignCenter()
            
            Button(action: {
                Haptics.fire(.light)
                if let url = URL(string: kAppStoreURL) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Update now")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.black)
                    .alignCenter()
                    .padding(.horizontal, kPadding)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 64)
            .padding(.top, 32)
            
            Spacer()
        }
        .padding(16)
        .background(Blur(style: .dark))
        .edgesIgnoringSafeArea(.all)
    }
}

struct AppVersionView_Previews: PreviewProvider {
    static var view: some View {
        ZStack {
            LandingView()
            AppVersionView()
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
