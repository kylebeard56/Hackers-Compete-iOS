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
    
    // 6:00 am to 9:59 am
    var isDawn: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        return hour >= 6 && hour < 10
    }
    
    // 10:00 am to 5:59 pm
    var isDay: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        return hour >= 10 && hour < 18
    }
    
    // 6:00 pm to 8:59 pm
    var isDusk: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        return hour >= 18 && hour < 21
    }
    
    // 9:00 pm to 5:59 am
    var isNight: Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: self)
        return hour >= 21 || hour < 6
    }
}
