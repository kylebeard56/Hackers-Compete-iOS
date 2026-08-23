//
//  Firebase+Rules.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//

import Firebase
import FirebaseFirestoreSwift
import Foundation
import SwiftUI

private let collection: String = Collections.rules.rawValue

extension FirebaseService {
    
    @discardableResult
    func getRule(by id: String, useCache: Bool = true) async -> Result<Rule, Error> {
        print(#function)
        
        let now: String = String(Date().timeIntervalSince1970)
        let queryKey = "cache/individual/\(collection)"
        let lastQueriedAt = UserDefaults.standard.string(forKey: queryKey)
        let lastQueriedTimestamp: Double = Double(lastQueriedAt ?? "") ?? 0.0
        
        do {
            /// Build query for firebase accordingly
            let query = database
                .collection(collection)
                .whereField("id", isEqualTo: id)
                .whereField(useCondition: useCache, "last_updated_at.unix", isGreaterThan: lastQueriedTimestamp)
            
            /// Fetch from API
            let data = try await getOne(of: Rule(), with: query).get()
            
            /// Write to cache and store timestamp
            await RealmService.shared.write(data, to: collection)
            UserDefaults.standard.set(now, forKey: queryKey)
            
            print("Rule [\(id)] fetched from API")
            return .success(data)
        } catch let error {
            if let err = error as? HackersError, err == .documentNotFound, useCache {
                /// Attempt to get from cache since API didn't return results.
                if let data = await RealmService.shared.read(of: Rule(), with: id) {
                    print("Pack [\(id)] fetched from local cache")
                    return .success(data)
                } else {
                    /// Document not found when we tried cache, try again ignoring cache (maybe timestamp issue).
                    return await getRule(by: id, useCache: false)
                }
            } else {
                return .failure(error)
            }
        }
    }
    
    @discardableResult
    func getRules(useCache: Bool = true) async -> Result<[Rule], Error> {
        print(#function)
        
        let now: String = String(Date().timeIntervalSince1970)
        let queryKey = "cache/batch/\(collection)"
        let lastQueriedAt = UserDefaults.standard.string(forKey: queryKey)
        let lastQueriedTimestamp: Double = Double(lastQueriedAt ?? "") ?? 0.0

        do {
            /// Build query for firebase accordingly
            let query = database
                .collection(collection)
                .whereField(useCondition: useCache, "last_updated_at.unix", isGreaterThan: lastQueriedTimestamp)

            /// Fetch from API with the appropriate filters
            let data = try await getMany(of: Rule(), with: query).get()

            /// Fetch cached packs prior to API call
            let cache = await RealmService.shared.read(of: Rule(), in: collection)

            /// Combine API and cache, sort by most updated first, and then remove duplicates (stale gets dropped)
            let rules = (data + cache).sorted(by: { $0.lastUpdatedAt.unix > $1.lastUpdatedAt.unix }).orderedUniques

            /// Write new data to cache and store timestamp for each
            for d in data {
                await RealmService.shared.write(d, to: collection)
                UserDefaults.standard.set(now, forKey: "cache/individual/\(collection)/\(d.id)")
            }

            /// Store batch timestamp
            UserDefaults.standard.set(now, forKey: queryKey)

            print("Rules: \(rules.count) total, \(data.count) fetched from API, \(cache.count) fetched from cache")
            return .success(rules)
        } catch let error {
            return .failure(error)
        }
    }
}
