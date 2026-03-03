//
//  Firebase+Storage.swift
//  Hackers
//
//  Created by Kyle Beard on 3/3/26.
//

import FirebaseStorage
import Foundation

// MARK: - Firebase Storage

extension FirebaseService {
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
}
