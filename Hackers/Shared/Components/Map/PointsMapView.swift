//
//  PointsMapView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/25.
//


import SwiftUI
import MapKit

struct PointsMapView: View {
    @State private var camera: MapCameraPosition
    let points: [CLLocationCoordinate2D]
    let iconName: String

    init(points: [CLLocationCoordinate2D],
         iconName: String = "mappin") {
        self.points = points
        self.iconName = iconName

        if let region = MKCoordinateRegion.fitting(points) {
            _camera = State(initialValue: .region(region))
        } else {
            _camera = State(initialValue: .automatic)
        }
    }

    /// Convenience init for a single coordinate
    init(coordinate: CLLocationCoordinate2D,
         iconName: String = "mappin") {
        self.init(points: [coordinate], iconName: iconName)
    }

    var body: some View {
        Map(position: $camera, interactionModes: .all) {
            ForEach(Array(points.enumerated()), id: \.offset) { _, coord in
                Annotation("", coordinate: coord, anchor: .bottom) {
                    PurpleIconAnnotation(iconName: iconName)
                }
            }
        }
    }
}

// MARK: - Custom purple annotation
private struct PurpleIconAnnotation: View {
    let iconName: String

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 34, height: 34)
                    .shadow(radius: 3, y: 1)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            // pointer
            Triangle()
                .fill(Color.purple)
                .frame(width: 10, height: 7)
                .offset(y: -1)
        }
        .accessibilityLabel("Map pin")
    }
}

// Simple triangle shape for the pointer
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

// MARK: - Fit region helper
extension MKCoordinateRegion {
    /// Creates a region that fits all coordinates with a little padding.
    static func fitting(_ coords: [CLLocationCoordinate2D],
                        minSpan: CLLocationDegrees = 0.01,
                        paddingFactor: Double = 0.25) -> MKCoordinateRegion? {
        guard !coords.isEmpty else { return nil }
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }

        var latDelta = max(maxLat - minLat, minSpan)
        var lonDelta = max(maxLon - minLon, minSpan)

        // add proportional padding
        latDelta += latDelta * paddingFactor
        lonDelta += lonDelta * paddingFactor

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
}

// MARK: - Preview / Usage
#Preview {
    let coords = [
        CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090), // Apple Park-ish
        CLLocationCoordinate2D(latitude: 37.3317, longitude: -122.0301)  // Nearby
    ]

    return VStack {
        PointsMapView(points: coords, iconName: "figure.golf")
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()

        PointsMapView(coordinate: CLLocationCoordinate2D(latitude: 40.7812, longitude: -73.9665),
                      iconName: "star.fill")
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
    }
}
