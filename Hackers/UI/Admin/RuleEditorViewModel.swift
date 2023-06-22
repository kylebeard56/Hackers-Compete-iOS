////
////  RuleEditorViewModel.swift
////  Hackers
////
////  Created by Kyle Beard on 11/10/22.
////
//
//import SwiftUI
//
//@MainActor
//class RuleEditorViewModel: Hackable {
//    @Published var rule: Rule = Rule()
//
//    @Published var isSubmitting: Bool = false
//    @Published var didSave: Bool = false
//    @Published var didFail: Bool = false
//    @Published var didReject: Bool = false
//
//    init(rule: Rule = Rule()) {
//        print("init RuleEditorViewModel for ID \(rule.id) with icon \(rule.icon.unicodeEscaped)")
//
//        self.rule = rule
//        if rule.id.isEmpty {
//            setPack()
//        }
//    }
//
//    deinit { print("deinit RuleEditorViewModel") }
//    
//    func setPack() {
//        rule.packID = "gameplay"
//        rule.type = RuleType.player.rawValue
//        rule.difficulty = RuleDifficulty.favor.rawValue
//    }
//
//    func clear() {
//        rule = Rule()
//        setPack()
//    }
//
//    @Sendable func save() async {
//        isSubmitting = true
//        defer { isSubmitting = false }
//
//        if rule.name.isEmpty
//            || rule.description.isEmpty
//            || rule.icon.isEmpty
//            || rule.type.isEmpty
//            || rule.difficulty.isEmpty
//            || rule.packID.isEmpty {
//            self.didReject = true
//            Haptics.fire(.error)
//            return
//        }
//
//        rule.lastUpdatedAt = Time()
//
//        do {
//            _ = try await rule.id.isEmpty ? rule.post().get() : rule.put().get()
//            self.didSave = true
//            rule.id = "" // We clear this out so we can POST a new rule instead of PUT without closing view.
//            Haptics.fire(.success)
//        } catch let error {
//            self.didFail = true
//            Haptics.fire(.error)
//            print("couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, \(error)")
//            self.addBreadcrumb(.error, .rules, "couldn't \(rule.id.isEmpty ? "POST" : "PUT") rule, error")
//        }
//    }
//}
