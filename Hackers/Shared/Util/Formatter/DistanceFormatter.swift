//
//  DistanceFormatter.swift
//  Hackers
//
//  Created by Kyle Beard on 8/15/25.
//

import CoreLocation
import Foundation

struct DistanceFormatter {
    static func formattedDistanceMiles(
        from location: CLLocation?,
        to latitude: Double,
        longitude: Double
    ) -> String? {
        guard let location else { return nil }
        let course = CLLocation(latitude: latitude, longitude: longitude)
        let meters = location.distance(from: course)
        let miles = meters / 1609.34
        return String(format: "%.1f miles", miles)
    }
}
