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
    
    var toTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: self)
    }
    
    func daysBetween(_ date: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
}
