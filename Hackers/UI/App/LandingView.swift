//
//  LandingView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/23/22.
//

import SwiftUI

/// Homepage with Play button
struct LandingView: View {
    @EnvironmentObject var appSession: AppSession
    
    @State private var navigateToPlayerEntry: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                background
                content
            }
            .environmentObject(appSession)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToPlayerEntry, destination: { PlayerEntry() })
        }
    }
    
    private var background: some View {
        ZStack {
            Image(uiImage: Asset.Images.splash.image)
                .resizable()
                .scaledToFill()
                .frame(height: UIScreen.main.bounds.height + 24) // Note: Unsure why but adding 24 works here.
                .clipped()
            Color.black.opacity(0.2)
        }
        .edgesIgnoringSafeArea(.vertical)
    }
    
    private var content: some View {
        VStack(spacing: kPadding) {
            Text("Hackers Golf")
                .font(.dmSans(size: 48, weight: .bold))
                .foregroundColor(.white)
            HStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: kPadding * 8, height: 2, alignment: .center)
                AwesomeImage(icon: .golfBallTee, style: .regular, size: 20, color: .white)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: kPadding * 8, height: 2, alignment: .center)
            }

            Text("The interactive card game to enhance your next round.")
                .font(.dmSans(size: 20, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            BigButton(
                title: "Play",
                labelColor: .black,
                buttonColor: .white,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    navigateToPlayerEntry = true
                    Haptics.fire(.light)
                }
            )
            .modifier(Shadow(opacity: 0.25, radius: 16, x: 0, y: 2))
        }
        .padding(kPadding)
        .padding(.vertical, kPadding * 3)
    }
}

struct LandingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LandingView()
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro")
            LandingView()
                .previewDevice("iPhone 8")
                .previewDisplayName("iPhone 8")
        }
    }
}
