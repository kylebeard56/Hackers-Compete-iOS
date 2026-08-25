//
//  AppStoreReview.swift
//  Hackers
//
//  Created by Kyle Beard on 4/3/23.
//

import StoreKit

enum AppStoreReviewManager {
    /// Criteria:
    ///  1. Must be at least 7 days in between prompts
    ///  2. Must have a certain amount of positive usages that would trigger review
    ///  3. Must be a different app version from last prompt.
    private static var eligibleForReviewPrompt: Bool {
        deviceDefaults.reviewPromptCount == 5
            && abs(Date(timeIntervalSince1970: deviceDefaults.reviewPromptLastTimestamp).daysBetween(Date())) >= 7
            && deviceDefaults.lastReviewRequestAppVersion != Bundle.main.appVersion
    }
    
    static func requestReview() {
        print(#function)
        deviceDefaults.reviewPromptCount += 1

        if eligibleForReviewPrompt {
            if let windowScene = UIApplication.shared.currentWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                
                // Reset and update defaults for next prompt
                deviceDefaults.reviewPromptCount = 0
                deviceDefaults.reviewPromptLastTimestamp = Date().timeIntervalSince1970
                deviceDefaults.lastReviewRequestAppVersion = Bundle.main.appVersion
                print("App store review prompt successful")
                return
            }
        }
        
        print("App store review prompt attempted, but not eligible")
    }

    static func writeReview() {
        let productURL = URL(string: kAppStoreURL)!
        var components = URLComponents(url: productURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "action", value: "write-review")]

        guard let writeReviewURL = components?.url else {
            print("url write review not found")
            return
        }

        UIApplication.shared.open(writeReviewURL)
    }
}
