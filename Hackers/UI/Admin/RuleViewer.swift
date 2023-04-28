//
//  RuleViewer.swift
//  Hackers
//
//  Created by Kyle Beard on 11/14/22.
//

import AlertToast
import SwiftUI

enum RuleViewType {
    case row, card
    
    var icon: Awesome {
        switch self {
        case .row:      return .rectangle
        case .card:     return .rows
        }
    }
}

struct RuleViewer: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appSession: AppSession
    
    @State private var viewModel: RuleEditorViewModel = RuleEditorViewModel()
    
    @State private var rules: [Rule] = []
    @State private var selectedRule: Rule = Rule()
    @State private var showRuleEditor: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var didDelete: Bool = false
    
    @State private var pack: PackName = .gameplay
    @State private var type: RuleType = .both
    @State private var difficulty: RuleDifficulty = .both
    @State private var showFilter: Bool = false
    
    @State private var gameplayCounts: [Int] = [0, 0, 0, 0]
    
    @State private var viewType: RuleViewType = .row
    
    private let kTestPlayer: Player = Player(name: "Kyle", color: .blue)
    
    var body: some View {
        ScrollView {
            VStack(spacing: kPadding) {
                ZStack {
                    Text("Rules")
                        .font(.dmSans(size: 20, weight: .bold))
                    
                    BackButton(icon: .xmark, onTap: { dismiss() })
                        .alignLeading()
                    
                    HStack(spacing: kPadding * 2) {
                        Button(action: {
                            if viewType == .card {
                                viewType = .row
                            } else {
                                viewType = .card
                            }
                        }) {
                            AwesomeImage(icon: viewType.icon, style: .regular, size: 20, color: .systemBlack)
                        }
                        
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
                        if viewType == .card {
                            ChaosCard(rule: rule, player: kTestPlayer, showShuffle: false)
                        } else {
                            ChaosRow(rule: rule, player: kTestPlayer)
                        }
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
        .task { await appSession.getRules() }
        .toast(isPresenting: $didDelete, alert: {
            AlertToast.messageHUD("See ya!", "This rule has been deleted.")
        })
        .onReceive(appSession.$rules, perform: { rules in
            self.rules = rules.sorted(by: { $0.name < $1.name })
            computeCounts()
        })
        .fullScreenCover(isPresented: $showRuleEditor, onDismiss: refreshRules) {
            RuleEditorView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showFilter) {
            RuleFilter(pack: $pack, type: $type, difficulty: $difficulty, onApply: filterRules, onClear: clearRules)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
        .padding(kPadding)
        .background(Color.systemGray6)
        .cornerRadius(8)
    }
    
    // MARK: - Filtering
    
    private func filterRules() {
        rules = appSession.rules.filter({ $0.packID == pack.rawValue })
        
        if type != .both {
            rules = rules.filter({ $0.type == type.rawValue })
        }
        
        if difficulty != .both {
            rules = rules.filter({ $0.difficulty == difficulty.rawValue })
        }
        
        rules = rules.sorted(by: { $0.name < $1.name })
        computeCounts()
    }
    
    private func clearRules() {
        rules = appSession.rules.sorted(by: { $0.name < $1.name })
        computeCounts()
    }
    
    private func computeCounts() {
        gameplayCounts[0] = rules.filter({ $0.isFavor && $0.isTeamRule}).count
        gameplayCounts[1] = rules.filter({ $0.isFavor && $0.isPlayerRule }).count
        gameplayCounts[2] = rules.filter({ $0.isChallenge && $0.isTeamRule}).count
        gameplayCounts[3] = rules.filter({ $0.isChallenge && $0.isPlayerRule}).count
    }
    
    // MARK: - Editing
    
    private func refreshRules() {
        Task {
            await appSession.getRules()
        }
    }
    
    private func newRule() {
        viewModel = RuleEditorViewModel()
        showRuleEditor = true
    }
    
    private func editRule() {
        viewModel = RuleEditorViewModel(rule: selectedRule)
        showRuleEditor = true
    }
    
    private func deleteRule() {
        Task {
            await selectedRule.delete()
            await appSession.getRules()
            didDelete = true
        }
    }
}

struct RuleViewer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RuleViewer()
                .environmentObject(AppSession())
                .lightModePreview()
            
            RuleViewer()
                .environmentObject(AppSession())
                .darkModePreview()
        }
    }
}
