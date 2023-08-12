//
//  ChaosRuleViewer.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/23.
//

import AlertToast
import SwiftUI

struct ChaosRuleViewer: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var viewModel: ChaosEditorViewModel = ChaosEditorViewModel()
    
    @State private var rules: [Rule] = []
    @State private var selectedRule: Rule = Rule()
    @State private var showRuleEditor: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var didDelete: Bool = false
    
    @State private var type: RuleType = .both
    @State private var difficulty: RuleDifficulty = .both
    @State private var showFilter: Bool = false
    
    @State private var gameplayCounts: [Int] = [0, 0, 0, 0]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Text("Rules")
                        .font(.dmSans(size: 20, weight: .bold))
                    
                    BackButton(icon: .xmark, onTap: { dismiss() })
                        .alignLeading()
                    
                    HStack(spacing: 40) {
                        Button(action: { showFilter = true }) {
                            AwesomeImage(icon: .filter, style: .regular, size: 20, color: .systemBlack)
                        }
                        
                        Button(action: newRule) {
                            AwesomeImage(icon: .squarePlus, style: .regular, size: 20, color: .systemBlack)
                        }
                    }
                    .alignTrailing()
                }
                
                gameplayMetrics

                ForEach(rules, id: \.self) { rule in
                    Button(action: {
                        selectedRule = rule
                        showConfirmation = true
                    }) {
                        ChaosRow(rule: rule, player: Player(name: rule.isTeamRule ? "Team" : "Player"))
                    }
                    .confirmationDialog("", isPresented: $showConfirmation) {
                        Button("Edit", role: .none) { editRule() }
                        Button("Delete", role: .destructive) { deleteRule() }
                    }
                }
            }
            .padding(20)
        }
        .environmentObject(roundSession)
        .background(Color.systemViewBackground)
        .onAppear() {
            refreshRules()
        }
        .toast(isPresenting: $didDelete, alert: {
            AlertToast.messageHUD("See ya!", "This rule has been deleted.")
        })
        .fullScreenCover(isPresented: $showRuleEditor, onDismiss: refreshRules) {
            ChaosRuleEditorView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilter) {
            ChaosRuleFilter(type: $type, difficulty: $difficulty, onApply: filterRules)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func refreshRules() {
        Task {
            do {
                let r = try await FirebaseService.shared.getRules().get()
                self.rules = r.sorted(by: { $0.name < $1.name })
                self.computeCounts()
            } catch let error {
                print("couldn't load rules, \(error)")
            }
        }
    }
    
    // MARK: - Metrics
    
    private var gameplayMetrics: some View {
        ZStack {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("Team")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("Player")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("Both")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    Text("Easy")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[0])")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[1])")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[0] + gameplayCounts[1])")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    Text("Hard")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[2])")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[3])")
                        .font(.dmSans(size: 17, weight: .regular))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[2] + gameplayCounts[3])")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
                
                Divider()
                
                HStack(alignment: .center, spacing: 8) {
                    Text("Both")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[0] + gameplayCounts[2])")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(gameplayCounts[1] + gameplayCounts[3])")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                    Text("\(rules.count)")
                        .font(.dmSans(size: 17, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignCenter()
                }
            }
            HStack {
                Spacer()
                Rectangle()
                    .frame(width: 1)
                Spacer()
                Rectangle()
                    .frame(width: 1)
                Spacer()
                Rectangle()
                    .frame(width: 1)
                Spacer()
            }
            .foregroundStyle(Color.systemGray4)
        }
        .padding(20)
        .background(Color.systemGray6)
        .cornerRadius(8)
    }
    
    // MARK: - Filtering
    
    private func filterRules() {
        Task {
            do {
                rules = try await FirebaseService.shared.getRules().get() ?? []
                
                if type != .both {
                    rules = rules.filter({ $0.type == type.rawValue })
                }
                
                if difficulty != .both {
                    rules = rules.filter({ $0.difficulty == difficulty.rawValue })
                }
                
                rules = rules.sorted(by: { $0.name < $1.name })
                computeCounts()
            } catch let _ {
                print("couldn't get rules to filter")
            }
        }
    }
    
    private func computeCounts() {
        gameplayCounts[0] = rules.filter({ $0.isFavor && $0.isTeamRule}).count
        gameplayCounts[1] = rules.filter({ $0.isFavor && $0.isPlayerRule }).count
        gameplayCounts[2] = rules.filter({ $0.isChallenge && $0.isTeamRule}).count
        gameplayCounts[3] = rules.filter({ $0.isChallenge && $0.isPlayerRule}).count
    }
    
    // MARK: - Editing
    
//    private func refreshRules() {
//        Task {
//            await appSession.getRules()
//        }
//    }
    
    private func newRule() {
        viewModel = ChaosEditorViewModel()
        showRuleEditor = true
    }
    
    private func editRule() {
        viewModel = ChaosEditorViewModel(r: selectedRule)
        showRuleEditor = true
    }
    
    private func deleteRule() {
        Task {
            await selectedRule.delete()
            didDelete = true
            HackersNotification.refreshChaosRules.send()
        }
    }
}

struct ChaosRuleViewer_Previews: PreviewProvider {
    static var previews: some View {
        ChaosRuleViewer()
    }
}
