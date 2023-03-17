//
//  DeviceSettings.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/23.
//

import Foundation
import LocalAuthentication
import SwiftyUserDefaults

protocol UserDefaultable: AnyObject {
    var launchCount: Int { get set }
    var acceptedTerms: Bool { get set }
    var lastKnownTermsVersion: String { get set }
    var welcomeTourTaken: Bool { get set }
    var joinedDrinkingWaitlist: Bool { get set }
}

class DeviceSettings: UserDefaultable {
    // Track the initial launch of the app (used to clear existing keychain should it have stayed).
    var launchCount: Int {
        get { UserDefaults.getStoredValue() ?? 0 }
        set { UserDefaults.setStoredValue(newValue) }
    }

    // Tracks whether the user accepted terms of service.
    var acceptedTerms: Bool {
        get { UserDefaults.getStoredValue() ?? false }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Tracks the last known terms updated for the user
    var lastKnownTermsVersion: String {
        get { UserDefaults.getStoredValue() ?? "0.0.0" }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Tracks whether the user took or skipped the welcome tour
    var welcomeTourTaken: Bool {
        get { UserDefaults.getStoredValue() ?? false }
        set { UserDefaults.setStoredValue(newValue) }
    }
    
    // Tracks whether the user submitted their email to join the drinking pack waitlist.
    var joinedDrinkingWaitlist: Bool {
        get { UserDefaults.getStoredValue() ?? false }
        set { UserDefaults.setStoredValue(newValue) }
    }
}

extension UserDefaults {
    /// Get stored value of key defaulting to the standard UserDefaults
    static func getStoredValue<T>(
        with key: String = #function,
        for id: String = "",
        inUserDefaults userDefaults: UserDefaults = .standard
    ) -> T? {
        userDefaults.object(forKey: key + id) as? T
    }

    /// Set stored value of key defaulting to the standard UserDefaults
    static func setStoredValue<T>(
        _ value: T,
        with key: String = #function,
        for id: String = "",
        inUserDefaults userDefaults: UserDefaults = .standard
    ) {
        userDefaults.setValue(value, forKey: key + id)
    }
}
