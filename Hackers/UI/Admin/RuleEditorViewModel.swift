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
    
    init() {
        print("init RuleEditorViewModel")
    }
    deinit { }
    
    func load(_ r: Rule) {
        if r.id.isEmpty {
            setPack(id: PackName.gameplay.rawValue)
            rule.difficulty = RuleDifficulty.easy.rawValue
        } else {
            rule = r
        }
    }
    
    func setPack(id: String) {
        rule.packID = id
        if id == PackName.gameplay.rawValue {
            rule.type = RuleType.player.rawValue
        }
        if id == PackName.drinking.rawValue {
            rule.type = RuleType.hole.rawValue
        }
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
            return
        }
        
        do {
            _ = try await rule.id.isEmpty ? rule.post().get() : rule.put().get()
            self.didSave = true
        } catch let error {
            self.didFail = true
            print("couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, \(error)")
            self.addBreadcrumb(.error, .rules, "couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, error")
        }
    }
}
