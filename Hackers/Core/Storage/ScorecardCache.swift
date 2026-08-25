//
//  ScorecardCache.swift
//  Hackers
//
//  Created by Kyle Beard on 3/3/26.
//

import Foundation

// MARK: - Cache Model

struct ScorecardCacheEntry: Codable {
    let base64Image: String
    let lastFetchedAt: Time
}

// MARK: - Scorecard Cache

enum ScorecardCache {
    private static let subdirectory = "Scorecards"
    private static let fileExtension = "cache"

    /// Cache key format: `scorecard-{roundID}-{playerID}` (derived from StorageAsset.id which is `roundID_playerID`).
    static func cacheKey(for assetID: String) -> String {
        "scorecard-\(assetID.replacingOccurrences(of: "_", with: "-"))"
    }

    /// Path: `{CachesDirectory}/Scorecards/{key}.cache`
    private static func fileURL(for key: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent(subdirectory, isDirectory: true)
        return dir.appendingPathComponent("\(key).\(fileExtension)")
    }

    /// Ensures the Scorecards subdirectory exists. Call before first write.
    private static func ensureDirectoryExists() throws {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent(subdirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Loads a cache entry for the given key. Returns nil if file doesn't exist or decode fails.
    static func loadFromCache(key: String) -> ScorecardCacheEntry? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ScorecardCacheEntry.self, from: data)
    }

    /// Saves base64 image and timestamp to cache. Creates directory if needed.
    static func saveToCache(key: String, base64: String, lastFetchedAt: Time) throws {
        try ensureDirectoryExists()
        let entry = ScorecardCacheEntry(base64Image: base64, lastFetchedAt: lastFetchedAt)
        let data = try JSONEncoder().encode(entry)
        let url = fileURL(for: key)
        try data.write(to: url)
    }

    /// Deletes the cache file for the given key. Use when base64 decode fails (corrupt cache).
    static func deleteCache(key: String) {
        let url = fileURL(for: key)
        try? FileManager.default.removeItem(at: url)
    }
}
