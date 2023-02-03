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
    
    @discardableResult
    func getSession(by id: String) async -> Result<Session, Error> {
        print(#function)
        do {
            /// Build a query where we fetch by ID within the last 24 hours
            let query = database
                .collection(collection)
                .whereField("id", isEqualTo: id)
                .whereField("ended", isEqualTo: false)
                .whereField("created_at.unix", isGreaterThan: Date().timeIntervalSince1970 - 86400)
            let data = try await getOne(of: Session(), with: query).get()
            return .success(data)
        } catch let error {
            print("error \(#function), \(error)")
            return .failure(error)
        }
    }
    
    @discardableResult
    func getSession(using code: String) async -> Result<Session, Error> {
        print(#function)
        do {
            /// Build a query where we redeem off of code within the last 24 hours
            let query = database
                .collection(collection)
                .whereField("code", isEqualTo: code)
                .whereField("ended", isEqualTo: false)
                .whereField("created_at.unix", isGreaterThan: Date().timeIntervalSince1970 - 86400)
            let data = try await getOne(of: Session(), with: query).get()
            return .success(data)
        } catch let error {
            print("error \(#function), \(error)")
            return .failure(error)
        }
    }

    func observeSession(for id: String) {
        print(#function)
        
        /// NOTE: Assumption made that `getSession()` has been called to validate code and 24 hour window.
        
        sessionObserver = database.collection(collection).document(id).addSnapshotListener({ querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("error fetching snapshot, \(error ?? HackersError.unknownSnapshotError)")
                return
            }
            let pending = snapshot.metadata.hasPendingWrites
            print("session updated, pending writes? \(pending)")
            
            if !pending {
                print("session updated, not pending writes")
                do {
                    let data = try snapshot.data(as: Session.self)
                    HackersNotification.sessionUpdated.send(with: data)
                } catch let error {
                    print("session observer received snapshot but failed to decode, \(error)")
                    HackersNotification.sessionUpdated.send()
                }
            }
        })
    }
    
    func stopSessionObservation() {
        print(#function)
        sessionObserver?.remove()
    }
}
