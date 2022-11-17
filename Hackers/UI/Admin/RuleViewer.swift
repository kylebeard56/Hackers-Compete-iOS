//
//  RuleViewer.swift
//  Hackers
//
//  Created by Kyle Beard on 11/14/22.
//

import SwiftUI

struct RuleViewer: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    @State private var viewModel: RuleEditorViewModel = RuleEditorViewModel()
    
    @State private var selectedRule: Rule = Rule()
    @State private var showRuleEditor: Bool = false
    @State private var showConfirmation: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: kPadding) {
                ZStack {
                    Text("Rules")
                        .font(.dmSans(size: 20, weight: .bold))
                    
                    BackButton(icon: .xmark, onTap: { dismiss() })
                        .alignLeading()
                    
                    Button(action: {
                        Task { await appSession.getRules() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.dmSans(size: 20, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                    }
                    .alignTrailing()
                }

                ForEach(appSession.rules.sorted(by: { $0.name < $1.name }), id: \.self) { rule in
                    Button(action: {
                        selectedRule = rule
                        showConfirmation = true
                    }) {
                        GameplayCard(rule: rule, player: Player(id: "", name: "Kyle", color: .systemBlue))
                    }
                    .confirmationDialog("", isPresented: $showConfirmation) {
                        Button("Edit", role: .none) { editRule() }
                        Button("Delete", role: .destructive) { deleteRule() }
                    }
                }
            }
            .padding(kPadding)
        }
        .environmentObject(appSession)
        .fullScreenCover(isPresented: $showRuleEditor) {
            RuleEditorView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func editRule() {
        viewModel = RuleEditorViewModel(rule: selectedRule)
        showRuleEditor = true
    }
    
    private func deleteRule() {
        Task {
            await selectedRule.delete()
            await appSession.getRules()
        }
    }
}
