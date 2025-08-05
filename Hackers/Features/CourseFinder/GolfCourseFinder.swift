//
//  GolfCourseFinder.swift
//  Hackers
//
//  Created by Kyle Beard on 8/5/25.
//

import CoreLocation
import Foundation
import MapKit
import UIKit

struct GolfCoursePlacemark: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let placemark: MKPlacemark
    let distance: CLLocationDistance
    
    var formattedDistance: String {
        let distanceInMiles = 1609.34 / distance
        return String(format: "%.1f miles", distanceInMiles)
    }
    
    var address: String {
        let components = [
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ].compactMap { $0 }
        
        return components.joined(separator: ", ")
    }
}

@MainActor
final class GolfCourseFinder: ObservableObject, Loggable {
    @Published var golfCourses: [GolfCoursePlacemark] = []
    @Published var isSearching = false
    @Published var didSearch = false
    
    func findGolfCourses(near location: CLLocation, radius: CLLocationDistance = 10000) async throws {
        addBreadcrumb(#function)
        
        golfCourses = []
        isSearching = true
        defer { isSearching = false }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "golf course"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            golfCourses = fetchCourses(from: response, near: location)
            
            printPretty(golfCourses)
        } catch let error {
            addBreadcrumb(.warning, .golfCourseFinder, "failed to complete MKLocalSearch", error)
        }
    }
    
    private func fetchCourses(
        from response: MKLocalSearch.Response,
        near location: CLLocation
    ) -> [GolfCoursePlacemark] {
        guard response.mapItems.isPopulated else { return [] }
        
        let golfCourses = response.mapItems.compactMap { mapItem -> GolfCoursePlacemark? in
            guard let placemark = mapItem.placemark.location else { return nil }
            guard let name = mapItem.name else { return nil }
            
            let distance = location.distance(from: placemark)
            return GolfCoursePlacemark(name: name, placemark: mapItem.placemark, distance: distance)
        }
        
        return golfCourses.sorted { $0.distance < $1.distance }
    }
}
