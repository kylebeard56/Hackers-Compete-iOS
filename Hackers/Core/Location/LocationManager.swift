//
//  LocationManager.swift
//  Hackers
//
//  Created by Kyle Beard on 8/5/25.
//

import CoreLocation
import Foundation
import UIKit

@MainActor
final class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }
    
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable location services in Settings."
        @unknown default:
            break
        }
    }
    
}
// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    
    // Add 'nonisolated' to allow these methods to be called from background threads
     nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
         guard let location = locations.last else { return }
         // Use Task to safely update @Published properties on MainActor
         Task { @MainActor in
             self.location = location
             self.locationError = nil
         }
     }
     
     nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
         Task { @MainActor in
             self.locationError = "Failed to get location: \(error.localizedDescription)"
         }
     }
     
     nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
         Task { @MainActor in
             self.authorizationStatus = status
             if status == .authorizedWhenInUse || status == .authorizedAlways {
                 self.locationManager.requestLocation()
             }
         }
     }
}
