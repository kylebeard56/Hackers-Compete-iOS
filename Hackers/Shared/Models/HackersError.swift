//
//  Errors.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation

enum HackersError: Error {
    // MARK: - Auth
    
    case linkableUserNotFound
    case linkableCredentialNotFound
    
    // MARK: - Firebase
    
    case documentNotFound
    case invalidDocumentID
    case failedToEncodeDocument
    case sessionWriteFailed
    case unknownSnapshotError
    case userNotFound
    case roundNotFound
    
    // MARK: - Round / Lobby
    
    case playerNotFound
    case hostTransferRequiresCurrentHost
    
    // MARK: - Play
    
    case partyCodeTaken
    case roundExpired
    case redrawFailed
}
