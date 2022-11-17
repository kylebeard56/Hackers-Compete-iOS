//
//  RuleEditorViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//

import SwiftUI

@MainActor
class RuleEditorViewModel: Hackable {
    @Published var rule: Rule = Rule()
    @Published var isSubmitting: Bool = false
    @Published var didSave: Bool = false
    @Published var didFail: Bool = false
    @Published var didReject: Bool = false
    
    init(rule: Rule = Rule()) {
        print("init RuleEditorViewModel \(rule.icon.unicodeEscaped) \(rule.id)")
        
        self.rule = rule
        if rule.id.isEmpty {
            setPack(id: PackName.gameplay.rawValue)
        }
    }
    
    deinit { }
    
    func setPack(id: String) {
        rule.packID = id
        if id == PackName.gameplay.rawValue {
            rule.type = RuleType.player.rawValue
            rule.difficulty = RuleDifficulty.easy.rawValue
        }
        if id == PackName.drinking.rawValue {
            rule.type = RuleType.hole.rawValue
            rule.difficulty = RuleDifficulty.give.rawValue
        }
    }
    
    func clear() {
        rule = Rule()
        setPack(id: PackName.gameplay.rawValue)
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
        } catch let error {
            self.didFail = true
            Haptics.fire(.error)
            print("couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, \(error)")
            self.addBreadcrumb(.error, .rules, "couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, error")
        }
    }
}
