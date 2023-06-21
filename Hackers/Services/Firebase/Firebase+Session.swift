//
//  Firebase+Session.swift
//  Hackers
//
//  Created by Kyle Beard on 2/3/23.
//

import Firebase
import FirebaseFirestoreSwift
import Foundation
import SwiftUI

private let collection: String = Collections.sessions.rawValue
private var sessionObserver: ListenerRegistration?

extension FirebaseService {
    
    @discardableResult func getSession(by id: String, useCache: Bool = true) async -> Result<Session, Error> {
        print(#function)
        
        let now: String = String(Date().timeIntervalSince1970)
        let queryKey = "cache/individual/\(collection)"
        let lastQueriedAt = UserDefaults.standard.string(forKey: queryKey)
        let lastQueriedTimestamp: Double = Double(lastQueriedAt ?? "") ?? 0.0
        
        do {
            /// Build a query where we fetch by ID within the last 24 hours
            let query = database
                .collection(collection)
                .whereField("id", isEqualTo: id)
                .whereField(useCondition: useCache, "last_updated_at.unix", isGreaterThan: lastQueriedTimestamp)
            
            // Fetch from API
            let data = try await getOne(of: Session(), with: query).get()
            
            /// Write to cache and store timestamp
            await RealmService.shared.write(data, to: collection)
            UserDefaults.standard.set(now, forKey: queryKey)
            
            return .success(data)
        } catch let error {
            if let err = error as? HackersError, err == .documentNotFound, useCache {
                /// Attempt to get from cache since API didn't return results.
                if let data = await RealmService.shared.read(of: Session(), with: id) {
                    print("Session [\(id)] fetched from local cache")
                    return .success(data)
                } else {
                    /// Document not found when we tried cache, try again ignoring cache (maybe timestamp issue).
                    return await getSession(by: id, useCache: false)
                }
            } else {
                return .failure(error)
            }
        }
    }
    
    /// NOTE: This doesn't use Realm caching since we can't store party code uniquely AND we always want latest.
    @discardableResult func getSession(using code: String) async -> Result<Session, Error> {
        print("\(#function) for code [\(code)]")
        do {
            /// Build a query where we redeem off of code within the last 24 hours
            let query = database.collection(collection).whereField("code", isEqualTo: code.removeWhitespace)
            return .success(try await getOne(of: Session(), with: query).get())
        } catch let error {
            print("error \(#function), \(error)")
            return .failure(error)
        }
    }
    
    /// Checks whether the party code is available or not for a particular session
    @discardableResult func isPartyCodeTaken(_ code: String) async -> Bool {
        print("\(#function) for code [\(code)]")
        do {
            /// Build a query where we redeem off of code within the last 24 hours
            let query = database
                .collection(collection)
                .whereField("code", isEqualTo: code.removeWhitespace)
                .whereField("created_at.unix", isGreaterThan: Date().timeIntervalSince1970 - activeSessionTimeInterval)
            
            _ = try await getOne(of: Session(), with: query).get()
            return true
        } catch let error {
            print("error \(#function), \(error)")
            return false
        }
    }

    func observeSession(for id: String) {
        print(#function)
        stopSessionObservation()
        
        /// NOTE: Assumption made that `getSession()` has been called to validate code and 24 hour window.
        
        sessionObserver = database
            .collection(collection)
            .document(id)
            .addSnapshotListener(includeMetadataChanges: true) { querySnapshot, error in
                
            guard let snapshot = querySnapshot else {
                print("error fetching snapshot, \(error ?? HackersError.unknownSnapshotError)")
                return
            }
                
            // hasPendingWrites == TRUE means it hasn't written yet -> induces infinite loop of read/write...
            if !snapshot.metadata.hasPendingWrites {
                print("session updated, not pending writes")
                do {
                    let data = try snapshot.data(as: Session.self)
                    HackersNotification.sessionUpdated.send(with: data)
                } catch let error {
                    print("session observer received snapshot but failed to decode, \(error)")
                    HackersNotification.sessionUpdated.send()
                }
            }
        }
    }
    
    func stopSessionObservation() {
        print(#function)
        sessionObserver?.remove()
    }
}
