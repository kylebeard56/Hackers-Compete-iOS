//
//  Date.swift
//  Hackers
//
//  Created by Kyle Beard on 7/14/25.
//

import Foundation

extension Date {
    static var yesterday: Date {
        Date.now.addingTimeInterval(-86400)
    }
    
    static var tomorrow: Date {
        Date.now.addingTimeInterval(86400)
    }
    
    static func yearsAgo(_ years: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .year, value: -years, to: .now) ?? .distantPast
    }
    
    var toISO8601: String {
        ISO8601DateFormatter().string(from: self)
    }
    
    var isValidAge: Bool {
        let calendar = Calendar.current
        let thirteenYearsAgo = calendar.date(byAdding: .year, value: -13, to: Date()) ?? Date()
        return self <= thirteenYearsAgo
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
    
    /// Subtracting 13 years from today's date.
    static var minimumAgeDate: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: Date.now) ?? .now
    }
    
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }

    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(self)
    }

    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }
    
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }
    
    var toDisplayText: String {
        if self.isToday {
            return "Today"
        }
        if self.isTomorrow {
            return "Tomorrow"
        }
        return self.toShortFormat
    }
    
    var toAgeYears: String {
        let components = Calendar.current.dateComponents([.year, .month], from: self, to: Date())
        let y = components.year ?? 0
        let m = components.month ?? 0
        return "\(y) years, \(m) months"
    }

    func isInRange(of start: Date, and end: Date) -> Bool {
        return (start.timeIntervalSince1970...end.timeIntervalSince1970).contains(self.timeIntervalSince1970)
    }

    /// Formatting Resource: https://nsdateformatter.com/

    /// YYYY-MM-DD
    var toKeyFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current // Or use UTC with TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }
    
    /// MMM d
    var toShortFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMM d"
        return formatter.string(from: self)
    }
    
    /// MMMM d, yyyy
    var toTraditionalFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: self)
    }
    
    /// EEEE MMMM d
    var toShortFormatYearless: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: self)
    }
    
    /// EEEE MMMM d
    var toLongFormatYearless: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: self)
    }
}
