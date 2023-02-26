//
//  Firebase+Config.swift
//  Hackers
//
//  Created by Kyle Beard on 2/26/23.
//

import Firebase
import FirebaseFirestoreSwift
import Foundation
import SwiftUI

private let collection: String = Collections.configuration.rawValue
private let appVersion: String = "minimum_app_version"
private var appVersionObserver: ListenerRegistration?

struct ConfigurationValue: Hashable, Codable {
    var value: String
}

extension FirebaseService {

    func observeMinimumAppVersion() {
        print(#function)
        
        appVersionObserver = database
            .collection(collection)
            .document(appVersion)
            .addSnapshotListener(includeMetadataChanges: true) { querySnapshot, error in
                
            guard let snapshot = querySnapshot else {
                print("error fetching snapshot, \(error ?? HackersError.unknownSnapshotError)")
                return
            }
            
            if !snapshot.metadata.hasPendingWrites {
                print("app version updated, not pending writes")
                do {
                    let data = try snapshot.data(as: ConfigurationValue.self)
                    let mav = data.value
                    if mav.versionCompare(Bundle.main.appVersion) == .orderedDescending {
                        print("app version not met - current \(Bundle.main.appVersion), minimum: \(mav)")
                        HackersNotification.appVersionNotMet.send(with: true)
                    } else {
                        print("version sufficient - current \(Bundle.main.appVersion), minimum: \(mav)")
                        HackersNotification.appVersionNotMet.send(with: false)
                    }
                } catch let error {
                    print("app version observer received snapshot but failed to decode, \(error)")
                }
            }
        }
    }
    
    func stopAppVersionObserver() {
        print(#function)
        appVersionObserver?.remove()
    }
}
