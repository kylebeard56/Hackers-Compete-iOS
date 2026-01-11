//
//  AppData.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation

final actor AppData: Loggable {
    static let shared = AppData()
    
    private(set) var user: HackersUser?
    private(set) var currentTermsVersion: String?
    private(set) var currentPolicyVersion: String?
    
    init() { }
}

// MARK: - Firebase

//extension AppData {
//    enum DatabaseAction {
//        case post, put, delete
//    }
//    
//    func refresh<T: FirebaseIdentifiable>(
//        _ data: T,
//        for action: DatabaseAction,
//        from collection: String
//    ) async {
//        addBreadcrumb()
//        switch Collections(rawValue: collection) {
////        case .bookmarks:
////            if let bookmark = data as? Bookmark {
////                bookmarks?.upsert(bookmark)
////            }
//        default:
//            print("do nothing")
//        }
//    }
//}

// MARK: - User

extension AppData {
    func setUser(_ u: HackersUser) {
        addBreadcrumb()
        self.user = u
    }
    
    func clearUser() {
        addBreadcrumb()
        self.user = nil
    }
}

// MARK: - Legal

extension AppData {
    func setLegalVersions(terms: String, policy: String) {
        addBreadcrumb()
        self.currentTermsVersion = terms
        self.currentPolicyVersion = policy
    }
    
    func clearLegalVersion() {
        addBreadcrumb()
        self.currentTermsVersion = nil
        self.currentPolicyVersion = nil
    }
}
