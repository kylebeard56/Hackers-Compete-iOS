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

// MARK: - Legal
extension FirebaseService {
    func fetchLatestTermsVersion() async throws -> String {
        addBreadcrumb()
        return try await fetchLegalVersion(document: "terms_version")
    }
    
    func fetchLatestPolicyVersion() async throws -> String {
        addBreadcrumb()
        return try await fetchLegalVersion(document: "policy_version")
    }
    
    private func fetchLegalVersion(document: String) async throws -> String {
        addBreadcrumb()
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
}

// MARK: - Minimum App Version
extension FirebaseService {
    func observeMinimumAppVersion() {
        if appVersionObserver != nil { return }
        
        addBreadcrumb()
        appVersionObserver = Firestore.firestore()
            .collection(Collections.configuration.name)
            .document("minimum_app_version")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let snapshot = snapshot else {
                    self?.addBreadcrumb(
                        level: .error,
                        message: "Error fetching snapshot: \(String(describing: error))"
                    )
                    return
                }
                
                if !snapshot.metadata.hasPendingWrites {
                    do {
                        let data = try snapshot.data(as: ConfigurationValue.self)
                        self?.addBreadcrumb(message: "snapshot detected for minimum_app_version, \(data.value)")
                        HackersNotification.minimumAppVersionDetected.send(
                            with: Bundle.main.appVersion.isGreaterThanOrEqualTo(version: data.value)
                        )
                    } catch {
                        self?.addBreadcrumb(level: .error, message: "Error decoding app version snapshot", error: error)
                    }
                }
            }
    }

    func stopAppVersionObserver() {
        addBreadcrumb()
        appVersionObserver?.remove()
        appVersionObserver = nil
    }
}

// MARK: - Share Code Length
extension FirebaseService {
    func fetchShareCodeLength() async -> Int {
        addBreadcrumb()
        do {
            let value = try await Firestore.firestore()
                .collection(Collections.configuration.name)
                .document("share_code_length")
                .getDocument()
                .data(as: ConfigurationValue.self)
                .value
            return Int(value) ?? kShareCodeDefaultLength
        } catch let error {
            addBreadcrumb(level: .warning, message: "Failed to get share code length, using default", error: error)
            return kShareCodeDefaultLength
        }
    }
    
    func bumpShareCodeLength(to value: Int) async throws {
        addBreadcrumb(message: "Bump share code to \(value)")
        do {
            let ref = Firestore.firestore()
                .collection(Collections.configuration.name)
                .document("share_code_length")
            let data = ConfigurationValue(value: "\(value)")
            try await ref.setData(try data.toDictionary())
        } catch let error {
            throw error
        }
    }
}
