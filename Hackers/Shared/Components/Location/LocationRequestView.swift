//
//  LocationRequestView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/5/25.
//

import SwiftUI

struct LocationRequestView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var locationService: LocationService
    
    var theme: PaletteTheme = .primary
    private var palette: DesignPalette { theme.palette(for: colorScheme) }
    
    var body: some View {
        VStack(spacing: 16) {
            Image("LocationIsometric")
                .interpolation(.high)
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.45)
            
            Text(titleText)
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()
            
            Text(subtitleText)
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
                .alignCenter()
            
            PrimaryButton(
                appearance: .fill,
                title: ctaText,
                labelColor: Color.white,
                buttonColor: Color.accentGreen,
                fillWidth: false,
                isDisabled: .false,
                isLoading: .false,
                onTap: callToAction
            )
        }
        .padding(.horizontal, 16)
    }
    
    private var titleText: String {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            return "Location needed"
        default:
            return "Share your location"
        }
    }
    
    private var subtitleText: String {
        switch locationService.authorizationStatus {
        case .denied:
            return "Location access was denied. Enable it in Settings to discover golf courses in your area."
        case .restricted:
            return "Location access is restricted. Check your device settings to find nearby golf courses."
        default:
            return "We want your location so we can discover courses near you right now."
        }
    }
    
    private var ctaText: String {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Allow access"
        }
    }
    
    private func callToAction() {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        default:
            locationService.requestLocation()
        }
    }
}

#Preview {
    LocationRequestView()
        .environmentObject(LocationService())
}
