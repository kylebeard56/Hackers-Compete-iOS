//
//  Waitlist.swift
//  Hackers
//
//  Created by Kyle Beard on 3/7/23.
//

import Foundation

struct Waitlist: FirebaseIdentifiable {
    var id: String
    var email: String
    var reason: String
    var time: Time
    
    init(
        id: String = "",
        email: String = "" ,
        reason: String = "",
        time: Time = Time()
    ) {
        self.id = id
        self.email = email
        self.reason = reason
        self.time = time
    }
}


extension Waitlist {
    @discardableResult
    func post() async -> Result<Waitlist, Error> {
        return await self.post(to: Collections.waitlists.rawValue)
    }

    @discardableResult
    func put() async -> Result<Waitlist, Error> {
        return await self.put(to: Collections.waitlists.rawValue)
    }

    @discardableResult
    func delete() async -> Result<Bool, Error> {
        return await self.delete(from: Collections.waitlists.rawValue)
    }
}
