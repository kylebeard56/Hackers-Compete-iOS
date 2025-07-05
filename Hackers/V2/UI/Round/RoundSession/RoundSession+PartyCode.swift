//
//  RoundSession+PartyCode.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

extension RoundSession {
    func updatePartyCode(to code: String) async {
        print(#function)
        self.partyCodeTaken = false
        self.partyCodeNotSaved = false
        self.partyCodeUpdated = false
        
        self.isUpdatingPartyCode = true
        defer { self.isUpdatingPartyCode = false }
        
        /// 1. If party code is populated, ensure it's unique and not taken
        if !code.isEmpty, await FirebaseService.shared.isPartyCodeTaken(code) {
            self.partyCodeTaken = true
            return
        }
        
        /// 2. Store session with party code and update.
        do {
            self.session?.partyCode = code
            _ = try await self.session?.put().get()
            self.partyCodeUpdated = true
        } catch let error {
            self.addBreadcrumb(.error, .session, "Party code not saved", error)
            self.partyCodeNotSaved = true
        }
    }
}
