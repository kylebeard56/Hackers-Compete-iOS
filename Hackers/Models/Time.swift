//
//  Time.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//

import Foundation

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
