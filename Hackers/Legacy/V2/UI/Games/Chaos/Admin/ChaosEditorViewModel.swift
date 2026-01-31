//
//  ChaosEditorViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/23.
//

import SwiftUI

@MainActor class ChaosEditorViewModel: Hackable {
    @Published var rule: Rule = Rule()
    
    @Published var isSubmitting: Bool = false
    @Published var didSave: Bool = false
    @Published var didFail: Bool = false
    @Published var didReject: Bool = false
    
    init(r: Rule = Rule()) {
        print("init RuleEditorViewModel for ID \(r.id) with icon \(r.icon.unicodeEscaped)")
        
        self.rule = r
        if r.id.isEmpty {
            rule.packID = "chaos"
            rule.type = RuleType.player.rawValue
            rule.difficulty = RuleDifficulty.favor.rawValue
        }
    }
    
    deinit { print("deinit RuleEditorViewModel") }
    
    func clear() {
        self.rule = Rule()
        self.rule.packID = "chaos"
        self.rule.type = RuleType.player.rawValue
        self.rule.difficulty = RuleDifficulty.favor.rawValue
    }
    
    func save() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        if rule.name.isEmpty
            || rule.description.isEmpty
            || rule.icon.isEmpty
            || rule.type.isEmpty
            || rule.difficulty.isEmpty
            || rule.packID.isEmpty {
            self.didReject = true
            Haptics.fire(.error)
            return
        }
        
        rule.lastUpdatedAt = Time()
        
        do {
            _ = try await rule.id.isEmpty ? rule.post().get() : rule.put().get()
            self.didSave = true
            rule.id = "" // We clear this out so we can POST a new rule instead of PUT without closing view.
            Haptics.fire(.success)
            HackersNotification.refreshChaosRules.send()
        } catch let error {
            self.didFail = true
            Haptics.fire(.error)
            print("couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, \(error)")
            self.addBreadcrumb(.error, .rules, "couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, error")
        }
    }
}
