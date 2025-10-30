//
//  CourseMapView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/25.
//

import SwiftUI
import MapKit

struct CourseMapView: View {
    @State private var camera: MapCameraPosition
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let icon: String
    let interactionModes: MapInteractionModes
    private let coordinate: CLLocationCoordinate2D
    
    init(
        latitude: CLLocationDegrees,
        longitude: CLLocationDegrees,
        icon: String = "figure.golf",
        interactionModes: MapInteractionModes = [.zoom],
        meters: CLLocationDistance = 1600
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.icon = icon
        self.interactionModes = interactionModes
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: meters, longitudinalMeters: meters)
        _camera = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $camera, interactionModes: interactionModes) {
            Annotation("", coordinate: coordinate, anchor: .bottom) {
                CourseAnnotation(iconName: icon)
            }
        }
    }
}

// MARK: - Custom purple annotation
private struct CourseAnnotation: View {
    let iconName: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.accentPurple)
                    .frame(width: 34, height: 34)
                    .shadow(radius: 3, y: 1)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Triangle()
                .fill(Color.accentPurple)
                .frame(width: 10, height: 7)
                .offset(y: -1)
        }
        .accessibilityLabel("Map pin")
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    CourseMapView(latitude: 35.089096, longitude: -82.46709)
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
