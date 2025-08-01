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

struct HackersUser: FirebaseIdentifiable, Loggable {
    var id: String
    var email: String
    var metadata: UserMetadata
    var players: [PlayerProfile]
    var legal: UserLegal
//    var acceptedLegal: Bool
    var credits: Int
    var createdAt: Time
    var lastUpdatedAt: Time
    
    var collection = Collections.users.name
    
    init(
        id: String = "",
        email: String = "",
        players: [PlayerProfile] = [],
        metadata: UserMetadata = .init(),
        legal: UserLegal = .init(),
        credits: Int = 0,
        createdAt: Time = .init(),
        lastUpdatedAt: Time = .init()
    ) {
        self.id = id
        self.email = email
        self.players = players
        self.metadata = metadata
        self.legal = legal
        self.credits = credits
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, players, metadata, legal, credits
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

struct PlayerProfile: Hashable, Codable {
    var id: String
    var name: Name
    var rounds: [String]
    var handicaps: [Handicap]
    var isPrimary: Bool
    
    init(
        id: String,
        name: Name = .init(),
        rounds: [String] = [],
        handicaps: [Handicap] = [],
        isPrimary: Bool = false
    ) {
        self.id = id
        self.name = name
        self.rounds = rounds
        self.handicaps = handicaps
        self.isPrimary = isPrimary
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, rounds, handicaps
        case isPrimary = "is_primary"
    }
}

// MARK: - Name
struct Name: Hashable, Codable {
    var givenName: String
    var familyName: String

    init(givenName: String = "", familyName: String = "") {
        self.givenName = givenName
        self.familyName = familyName
    }

    enum CodingKeys: String, CodingKey {
        case givenName = "given_name"
        case familyName = "family_name"
    }

    var isEmpty: Bool {
        givenName.isEmpty || familyName.isEmpty
    }
    
    var isPopulated: Bool {
        givenName.isPopulated || familyName.isPopulated
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
        id: String = ID.string(),
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
