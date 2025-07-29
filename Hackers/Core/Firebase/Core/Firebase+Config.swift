//
//  Firebase+Config.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation

struct ConfigurationValue: Hashable, Codable {
    var value: String

    init(value: String = "") {
        self.value = value
    }
}

extension FirebaseService {
    func fetchLatestTermsVersion() async throws -> String {
        return try await fetchLegalVersion(document: "terms_version")
    }
    
    func fetchLatestPolicyVersion() async throws -> String {
        return try await fetchLegalVersion(document: "policy_version")
    }
    
    private func fetchLegalVersion(document: String) async throws -> String {
        do {
            return try await Firestore.firestore()
                .collection(Collections.configuration.name)
                .document(document)
                .getDocument()
                .data(as: ConfigurationValue.self)
                .value
        } catch let error {
            throw error
        }
    }
    
    func observeMinimumAppVersion() {
        if appVersionObserver != nil { return }
        
        addBreadcrumb(#function)
        appVersionObserver = Firestore.firestore()
            .collection(Collections.configuration.name)
            .document("minimum_app_version")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let snapshot = snapshot else {
                    self?.addBreadcrumb(.error, .firebase, "Error fetching snapshot: \(String(describing: error))")
                    return
                }
                
                if !snapshot.metadata.hasPendingWrites {
                    do {
                        let data = try snapshot.data(as: ConfigurationValue.self)
                        self?.addBreadcrumb("snapshot detected for minimum_app_version, \(data.value)")
                        HackersNotification.minimumAppVersionDetected.send(
                            with: Bundle.main.appVersion.isGreaterThanOrEqualTo(version: data.value)
                        )
                    } catch {
                        self?.addBreadcrumb(.error, .firebase, "Error decoding app version snapshot: \(error)")
                    }
                }
            }
    }

    func stopAppVersionObserver() {
        addBreadcrumb(#function)
        appVersionObserver?.remove()
        appVersionObserver = nil
    }
}
