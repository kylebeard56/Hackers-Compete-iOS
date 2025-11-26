//
//  HackersUser.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Firebase
import FirebaseFirestoreCombineSwift
import Foundation
import UIKit

enum UserStatus: String {
    case active, inactive
}

struct HackersUser: FirebaseIdentifiable, Loggable {
    var id: String
    var email: String
    var metadata: UserMetadata
    var players: [String]
    var legal: UserLegal
//    var acceptedLegal: Bool
    var credits: Int
    var status: String
    var createdAt: Time
    var lastUpdatedAt: Time
    
    var collection = Collections.users.name
    var schema: Int = 1
    
    init(
        id: String = "",
        email: String = "",
        players: [String] = [],
        metadata: UserMetadata = .init(),
        legal: UserLegal = .init(),
        credits: Int = 0,
        status: String = UserStatus.active.rawValue,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.email = email
        self.players = players
        self.metadata = metadata
        self.legal = legal
        self.credits = credits
        self.status = status
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, players, metadata, legal, credits, status, schema
        case createdAt = "created_at"
        case lastUpdatedAt = "last_updated_at"
    }
    
    var isEmpty: Bool {
        email.isEmpty && id.isEmpty
    }
    
    var isPopulated: Bool {
        email.isPopulated
    }
}

// MARK: - User Metadata
struct UserMetadata: Hashable, Codable {
    var deviceOS: String
    var latestVersion: String
    var lastLoginAt: Time
    
    init(
        deviceOS: String = systemVersion,
        latestVersion: String = Bundle.main.appVersion,
        lastLoginAt: Time = .init()
    ) {
        self.deviceOS = deviceOS
        self.latestVersion = latestVersion
        self.lastLoginAt = lastLoginAt
    }
    
    enum CodingKeys: String, CodingKey {
        case deviceOS = "device_operating_system"
        case latestVersion = "last_app_version"
        case lastLoginAt = "last_login_at"
    }
    
    mutating func update(includeLastLogin: Bool = false) {
        self.deviceOS = systemVersion
        self.latestVersion = Bundle.main.appVersion
        self.lastLoginAt = includeLastLogin ? Time() : self.lastLoginAt
    }
}

// MARK: - User Legal
struct UserLegal: Hashable, Codable {
    var terms: String
    var privacyPolicy: String
    var time: Time
    
    init(
        terms: String = "",
        privacyPolicy: String = ""
    ) {
        self.terms = terms
        self.privacyPolicy = privacyPolicy
        self.time = Time()
    }
    
    enum CodingKeys: String, CodingKey {
        case time
        case terms = "terms"
        case privacyPolicy = "privacy_policy"
    }
    
    /// Returns whether the latest accepted version by the user is greater than or equal to the expected terms version.
    func isTermsUpToDate(for version: String) -> Bool {
        print("\(#function), last accepted terms: \(self.terms), required terms: \(version)")
        return self.terms.isGreaterThanOrEqualTo(version: version)
    }
    
    func isPolicyUpToDate(for version: String) -> Bool {
        print("\(#function), last accepted policy: \(self.privacyPolicy), required policy: \(version)")
        return self.privacyPolicy.isGreaterThanOrEqualTo(version: version)
    }
}

// MARK: - Handicap
struct Handicap: Hashable, Codable {
    var id: String
    var name: String
    var value: Int
    var isDefault: Bool
    
    init(
        id: String = HackersID.string(),
        name: String = "",
        value: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.isDefault = isDefault
    }
}

// MARK: - Time
struct Time: Hashable, Codable {
    var iso: String
    var unix: Double
    
    init(iso: String, unix: Double) {
        self.iso = iso
        self.unix = unix
    }
    
    init(for date: Date = Date()) {
        self.iso = date.toISO8601
        self.unix = date.timeIntervalSince1970
    }
    
    var beginningOfTime: Time {
        Time(iso: "1970-01-01T00:00:00Z", unix: 0)
    }
    
    var endOfTIme: Time {
        Time(iso: "3000-01-01T23:59:59Z", unix: 32503766399)
    }
}
