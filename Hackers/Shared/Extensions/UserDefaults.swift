//
//  UserDefaults.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import SwiftUI
import SwiftyUserDefaults

// MARK: - Protocol Definition
protocol Defaultable: Sendable {
    /// Launch
    func getLaunchCount() async -> Int
    func setLaunchCount(_ value: Int) async

    /// Legal
    func getAcceptedTermsOfUse() async -> [String]
    func setAcceptedTermsOfUse(_ value: [String]) async
    
    func getAcceptedPrivacyPolicy() async -> [String]
    func setAcceptedPrivacyPolicy(_ value: [String]) async

    /// App Store Review
    func getReviewPromptCount() async -> Int
    func setReviewPromptCount(_ value: Int) async

    func getReviewPromptLastTimestamp() async -> Double
    func setReviewPromptLastTimestamp(_ value: Double) async

    func getLastReviewRequestAppVersion() async -> String
    func setLastReviewRequestAppVersion(_ value: String) async

    /// User Config
    func getHapticsEnabled() async -> Bool
    func setHapticsEnabled(_ value: Bool) async

    func getPushNotificationsEnabled() async -> Bool
    func setPushNotificationsEnabled(_ value: Bool) async

    func getLocationEnabled() async -> Bool
    func setLocationEnabled(_ value: Bool) async
    
    /// Auth
    func getUserGivenName() async -> String
    func setUserGivenName(_ value: String) async

    func getUserFamilyName() async -> String
    func setUserFamilyName(_ value: String) async

    func getUserEmail() async -> String
    func setUserEmail(_ value: String) async

    func getAppleAuthID() async -> String
    func setAppleAuthID(_ value: String) async

    func getGoogleAuthID() async -> String
    func setGoogleAuthID(_ value: String) async

    /// Home Course
    func getHomeCourseApiID() async -> Int?
    func setHomeCourseApiID(_ value: Int?) async
    func getHomeCourseName() async -> String?
    func setHomeCourseName(_ value: String?) async
    func getHomeCourseTeeID() async -> String?
    func setHomeCourseTeeID(_ value: String?) async
}

// MARK: - Property Wrapper
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    let userDefaults: UserDefaults
    
    init(key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    var wrappedValue: T {
        get { userDefaults.object(forKey: key) as? T ?? defaultValue }
        set { userDefaults.setValue(newValue, forKey: key) }
    }
}

// MARK: - Actor Implementation
actor Defaults: Defaultable {
    static let shared = Defaults()
    private init() { }

    @UserDefault(key: "launchCount", defaultValue: 0)
    private var launchCount: Int

    @UserDefault(key: "acceptedTermsOfUse", defaultValue: [])
    private var acceptedTermsOfUse: [String]
    
    @UserDefault(key: "acceptedPrivacyPolicy", defaultValue: [])
    private var acceptedPrivacyPolicy: [String]

    @UserDefault(key: "reviewPromptCount", defaultValue: 0)
    private var reviewPromptCount: Int

    @UserDefault(key: "reviewPromptLastTimestamp", defaultValue: 0.0)
    private var reviewPromptLastTimestamp: Double

    @UserDefault(key: "lastReviewRequestAppVersion", defaultValue: "")
    private var lastReviewRequestAppVersion: String

    @UserDefault(key: "hapticsEnabled", defaultValue: true)
    private var hapticsEnabled: Bool

    @UserDefault(key: "pushNotificationsEnabled", defaultValue: false)
    private var pushNotificationsEnabled: Bool
    
    @UserDefault(key: "locationEnabled", defaultValue: false)
    private var locationEnabled: Bool

    @UserDefault(key: "userGivenName", defaultValue: "")
    private var userGivenName: String

    @UserDefault(key: "userFamilyName", defaultValue: "")
    private var userFamilyName: String

    @UserDefault(key: "userEmail", defaultValue: "")
    private var userEmail: String

    @UserDefault(key: "appleAuthID", defaultValue: "")
    private var appleAuthID: String

    @UserDefault(key: "googleAuthID", defaultValue: "")
    private var googleAuthID: String

    @UserDefault(key: "homeCourseApiID", defaultValue: 0)
    private var homeCourseApiID: Int

    @UserDefault(key: "homeCourseName", defaultValue: "")
    private var homeCourseName: String

    @UserDefault(key: "homeCourseTeeID", defaultValue: "")
    private var homeCourseTeeID: String

    // MARK: - Protocol Implementation

    // Launch
    func getLaunchCount() async -> Int { launchCount }
    func setLaunchCount(_ value: Int) async { launchCount = value }
    func incrementLaunchCount() async { launchCount += 1 }
    
    // Legal
    func getAcceptedTermsOfUse() async -> [String] { acceptedTermsOfUse }
    func setAcceptedTermsOfUse(_ value: [String]) async { acceptedTermsOfUse = value }
    func acceptNewTermsOfUse(_ value: String) async { acceptedTermsOfUse.append(value) }

    func getAcceptedPrivacyPolicy() async -> [String] { acceptedPrivacyPolicy }
    func setAcceptedPrivacyPolicy(_ value: [String]) async { acceptedPrivacyPolicy = value }
    func acceptNewPrivacyPolicy(_ value: String) async { acceptedPrivacyPolicy.append(value) }
    
    // App Store Review
    func getReviewPromptCount() async -> Int { reviewPromptCount }
    func setReviewPromptCount(_ value: Int) async { reviewPromptCount = value }

    func getReviewPromptLastTimestamp() async -> Double { reviewPromptLastTimestamp }
    func setReviewPromptLastTimestamp(_ value: Double) async { reviewPromptLastTimestamp = value }

    func getLastReviewRequestAppVersion() async -> String { lastReviewRequestAppVersion }
    func setLastReviewRequestAppVersion(_ value: String) async { lastReviewRequestAppVersion = value }

    // User Config
    func getHapticsEnabled() async -> Bool { hapticsEnabled }
    func setHapticsEnabled(_ value: Bool) async { hapticsEnabled = value }

    func getPushNotificationsEnabled() async -> Bool { pushNotificationsEnabled }
    func setPushNotificationsEnabled(_ value: Bool) async { pushNotificationsEnabled = value }

    func getLocationEnabled() async -> Bool { locationEnabled }
    func setLocationEnabled(_ value: Bool) async { locationEnabled = value }
    
    // Auth
    func getUserGivenName() async -> String { userGivenName }
    func setUserGivenName(_ value: String) async { userGivenName = value }

    func getUserFamilyName() async -> String { userFamilyName }
    func setUserFamilyName(_ value: String) async { userFamilyName = value }

    func getUserEmail() async -> String { userEmail }
    func setUserEmail(_ value: String) async { userEmail = value }

    func getAppleAuthID() async -> String { appleAuthID }
    func setAppleAuthID(_ value: String) async { appleAuthID = value }

    func getGoogleAuthID() async -> String { googleAuthID }
    func setGoogleAuthID(_ value: String) async { googleAuthID = value }

    // Home Course
    func getHomeCourseApiID() async -> Int? {
        let id = homeCourseApiID
        return id > 0 ? id : nil
    }
    func setHomeCourseApiID(_ value: Int?) async {
        homeCourseApiID = value ?? 0
    }
    func getHomeCourseName() async -> String? {
        let name = homeCourseName
        return name.isPopulated ? name : nil
    }
    func setHomeCourseName(_ value: String?) async {
        homeCourseName = value ?? ""
    }
    func getHomeCourseTeeID() async -> String? {
        let id = homeCourseTeeID
        return id.isPopulated ? id : nil
    }
    func setHomeCourseTeeID(_ value: String?) async {
        homeCourseTeeID = value ?? ""
    }
}
