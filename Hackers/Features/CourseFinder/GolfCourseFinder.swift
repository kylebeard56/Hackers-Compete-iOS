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
        let distanceInMiles = distance / 1609.34
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
    
    var normalizedName: String {
        CourseNameNormalizer.normalize(name)
    }
}

struct GolfCourseFinder: Loggable {
    var location: CLLocation
    var radius: CLLocationDistance
    
    init(for location: CLLocation, with radius: CLLocationDistance = 10000) {
        self.location = location
        self.radius = radius
    }
    
    func findGolfCourses() async throws -> [GolfCoursePlacemark] {
        addBreadcrumb(#function)
        
        let request = MKLocalSearch.Request()
        request.pointOfInterestFilter = .init(including: [.golf, .miniGolf])
        request.naturalLanguageQuery = "golf courses"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        
        let search = MKLocalSearch(request: request)
        
        do {
            return fetchCourses(from: try await search.start())
        } catch let error {
            addBreadcrumb(.warning, .golfCourseFinder, "failed to complete MKLocalSearch and fetch", error)
            throw error
        }
    }
    
    private func fetchCourses(from response: MKLocalSearch.Response) -> [GolfCoursePlacemark] {
        guard response.mapItems.isPopulated else { return [] }
        
        let golfCourses = response.mapItems.compactMap { mapItem -> GolfCoursePlacemark? in
            printPretty(mapItem)
            guard let placemark = mapItem.placemark.location else { return nil }
            guard let name = mapItem.name else { return nil }
            //guard let poi = mapItem.pointOfInterestCategory, [.golf, .miniGolf].contains(poi) else { return nil }
            
            let distance = location.distance(from: placemark)
            return GolfCoursePlacemark(name: name, placemark: mapItem.placemark, distance: distance)
        }
        
        return golfCourses.sorted { $0.distance < $1.distance }
    }
}
