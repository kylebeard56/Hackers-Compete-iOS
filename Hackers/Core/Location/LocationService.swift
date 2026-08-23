//
//  LocationService.swift
//  Hackers
//
//  Created by Kyle Beard on 8/5/25.
//

import Combine
import CoreLocation
import Foundation
import UIKit

@MainActor
final class LocationService: NSObject, ObservableObject, Loggable {
    private let locationService = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    private var subscriptions = Set<AnyCancellable>()
        
    override init() {
        super.init()
        locationService.delegate = self
        locationService.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        $authorizationStatus
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { value in
                HackersNotification.locationAuthorizationChanged.send(with: value)
            })
            .store(in: &subscriptions)
        
        $location
            .subscribe(on: DispatchQueue.main)
            .sink(receiveValue: { value in
                HackersNotification.locationUpdated.send(with: value)
            })
            .store(in: &subscriptions)
    }
    
    func requestLocation() {
        addBreadcrumb()
        switch authorizationStatus {
        case .notDetermined:
            locationService.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationService.requestLocation()
        case .denied, .restricted:
            locationError = "Location access denied. Please enable location services in Settings."
            addBreadcrumb(level: .warning, message: "user has denied or restricted location services.")
        @unknown default:
            break
        }
    }
    
}

extension LocationService: CLLocationManagerDelegate {
    
    // Add 'nonisolated' to allow these methods to be called from background threads
     nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
         
         guard let location = locations.last else { return }
         // Use Task to safely update @Published properties on MainActor
         
         addBreadcrumb(message: "Location updated to coordinates: \(location.coordinate)")
         Task { @MainActor in
             self.location = location
             self.locationError = nil
         }
     }
     
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        addBreadcrumb()
         Task { @MainActor in
             self.locationError = "Failed to get location: \(error.localizedDescription)"
         }
     }
     
     nonisolated func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
     ) {
         addBreadcrumb(message: "Location authorization changed to \(status.prettyName)")
         Task { @MainActor in
             self.authorizationStatus = status
             if status == .authorizedWhenInUse || status == .authorizedAlways {
                 self.locationService.requestLocation()
             }
         }
     }
}

extension CLAuthorizationStatus {
    var prettyName: String {
        switch self {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        case .authorized:
            return "authorized"
        default:
            return "unknown"
        }
    }
    
    var isAuthorized: Bool {
        [.authorizedAlways, .authorizedWhenInUse].contains(self)
    }
}
