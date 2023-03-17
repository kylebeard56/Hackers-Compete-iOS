//
//  Date.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//

import Foundation

extension Date {
    var toISO8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
    
    var relativeTimeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date.now)
    }
}
