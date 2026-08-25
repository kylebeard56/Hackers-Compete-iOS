//
//  SuggestionBoxViewModel.swift
//  Hackers
//
//  Created by Kyle Beard on 8/27/23.
//

import Foundation
import SwiftUI

@MainActor class SuggestionBoxViewModel: Hackable {
    @Published var email: String = ""
    @Published var text: String = ""
    @Published var submitting: Bool = false
    @Published var submitted: Bool = false
    @Published var showErrorBanner: Bool = false
    
    init() { print("init SuggestionBoxViewModel") }
    deinit { print("deinit SuggestionBoxViewModel") }
    
    @Sendable func post() async {
        self.submitting = true
        self.showErrorBanner = false
        
        do {
            _ = try await SuggestionBox(email: email, text: text).post(to: CollectionsV2.suggestionBox.rawValue).get()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                Haptics.fire(.success)
                withAnimation(.linear(duration: 0.2)) {
                    self.submitted = true
                    self.submitting = false
                }
            })
        } catch let error {
            addBreadcrumb(.error, .suggestionBox, "Suggestion box failed", error)
            Haptics.fire(.error)
            withAnimation(.linear(duration: 0.2)) {
                self.showErrorBanner = true
                self.submitting = false
            }
        }
    }
}
