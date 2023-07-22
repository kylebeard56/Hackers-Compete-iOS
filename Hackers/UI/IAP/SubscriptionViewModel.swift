//
//  SubscriptionViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 7/21/23.
//

import Foundation
import StoreKit

// https://www.revenuecat.com/blog/engineering/ios-in-app-subscription-tutorial-with-storekit-2-and-swift/

enum SubscriptionOption {
    case yearly
    case monthly
    case lifetime
    
    var title: String {
        switch self {
        case .yearly:       return "$9.99/yr"
        case .monthly:      return "$2.99/mo"
        case .lifetime:     return "$49.99/once"
        }
    }
    
    var subtitle: String {
        switch self {
        case .yearly:       return "after a 14 day trial"
        case .monthly:      return "and cancel anytime"
        case .lifetime:     return "and have it for a lifetime"
        }
    }
    var icon: String {
        switch self {
        case .yearly:       return "f133"
        case .monthly:      return "f073"
        case .lifetime:     return "f534"
        }
    }
}

@MainActor class SubscriptionViewModel: Hackable {
    
    @Published var isEligibleForTrial: Bool = true
    @Published var selectedOption: SubscriptionOption = .yearly
    @Published var isPurchasing: Bool = false
    
    init() { }
    deinit { }
}
