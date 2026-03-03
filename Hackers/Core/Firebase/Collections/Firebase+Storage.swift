//
//  Firebase+Storage.swift
//  Hackers
//
//  Created by Kyle Beard on 3/3/26.
//

import FirebaseStorage
import Foundation
import UIKit

// MARK: - Firebase Storage

extension FirebaseService {
    /// JPEG compression quality for scorecard uploads. 0.7 balances size and readability.
    static let scorecardCompressionQuality: CGFloat = 0.7

    /// Uploads a scorecard image and returns a `StorageAsset` describing the stored file.
    /// Path: scorecards/{roundID}/{playerID}.jpg
    /// Bucket: gs://hackers-compete-sandbox.firebasestorage.app
    func uploadScorecard(imageData: Data, roundID: String, playerID: String) async throws -> StorageAsset {
        addBreadcrumb(message: "\(#function), round: \(roundID), player: \(playerID)")

        let storage = Storage.storage(url: "gs://hackers-compete-sandbox.firebasestorage.app")
        let path = "scorecards/\(roundID)/\(playerID).jpg"
        let ref = storage.reference(withPath: path)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(imageData, metadata: metadata)

        let assetID = "\(roundID)_\(playerID)"
        return StorageAsset(
            id: assetID,
            path: path,
            lastModifiedAt: .init()
        )
    }

    /// Downloads raw bytes for a scorecard from Firebase Storage.
    func downloadScorecard(asset: StorageAsset) async throws -> Data {
        addBreadcrumb(message: "\(#function), asset: \(asset.id)")
        let storage = Storage.storage(url: "gs://hackers-compete-sandbox.firebasestorage.app")
        let ref = storage.reference(withPath: asset.path)
        let maxSize: Int64 = 5 * 1024 * 1024 // 5MB
        return try await ref.data(maxSize: maxSize)
    }

    /// Fetches a scorecard image with cache. Returns nil if asset is missing or download fails.
    /// Cache key: scorecard-{roundID}-{playerID}. Re-downloads when asset.lastModifiedAt > cache.lastFetchedAt.
    func fetchScorecardImage(asset: StorageAsset) async throws -> UIImage? {
        let key = ScorecardCache.cacheKey(for: asset.id)

        // 1. Check cache
        if let entry = ScorecardCache.loadFromCache(key: key),
           asset.lastModifiedAt.unix <= entry.lastFetchedAt.unix {
            if let data = Data(base64Encoded: entry.base64Image),
               let image = UIImage(data: data) {
                return image
            }
            // Corrupt cache: delete and re-download
            ScorecardCache.deleteCache(key: key)
        }

        // 2. Download from Storage
        let data = try await downloadScorecard(asset: asset)
        guard let image = UIImage(data: data) else { return nil }

        // 3. Save to cache
        let base64 = data.base64EncodedString()
        let lastFetchedAt = Time(for: Date())
        try? ScorecardCache.saveToCache(key: key, base64: base64, lastFetchedAt: lastFetchedAt)

        return image
    }
}
