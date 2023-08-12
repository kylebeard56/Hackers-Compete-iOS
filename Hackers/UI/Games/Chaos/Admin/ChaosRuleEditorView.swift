//
//  ChaosRuleEditorView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/12/23.
//

import AlertToast
import Introspect
import SwiftUI

enum HolePar: Int {
    case none = 0
    case three = 3
    case four = 4
    case five = 5
}

enum HoleCondition: String {
    case water
    case bunkers
    case trees
    case wind
    
    var displayName: String {
        switch self {
        case .water:        return "Water"
        case .bunkers:      return "Bunkers"
        case .trees:        return "Trees"
        case .wind:         return "Wind"
        }
    }
    
    var icon: Awesome {
        switch self {
        case .water:    return .water
        case .bunkers:  return .umbrellaBeach
        case .trees:    return .trees
        case .wind:     return .wind
        }
    }
}

struct ChaosRuleEditorView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: ChaosEditorViewModel
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case name, description, icon }
    
    var body: some View {
        ZStack {
            ScrollView {
                content
            }
            
            if focusedField != nil {
                ZStack {
                    Circle()
                        .fill(Color.systemCard)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 0)
                    Button(action: {
                        Haptics.fire(.light)
                        UIApplication.shared.endEditing()
                    }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .bold()
                            .foregroundColor(Color.systemBlack)
                    }
                }
                .alignTrailing()
                .alignBottom()
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            
            VStack {
                BigButton(
                    style: .solid,
                    title: "Save",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: $viewModel.isSubmitting,
                    onTap: {
                        Task { await viewModel.save() }
                    }
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .alignBottom()
            .ignoresSafeArea(.keyboard)
        }
        .background(Color.systemViewBackground)
        .toast(isPresenting: $viewModel.didSave, alert: {
            AlertToast.successHUD("Woohoo!", "This rule has been saved.")
        })
        .toast(isPresenting: $viewModel.didFail, alert: {
            AlertToast.errorHUD("Hmm...", "This rule couldn't be saved.")
        })
        .toast(isPresenting: $viewModel.didReject, alert: {
            AlertToast.errorHUD("Oops!", "This rule is incomplete.")
        })
//        .onReceive(viewModel.$didSave, perform: { value in
//            if value {
//                refreshRules()
//            }
//        })
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ZStack {
                        BackButton(icon: .xmark, onTap: { dismiss() })
                            .alignLeading()
                        
                        Text("Rule \(viewModel.rule.id.isEmpty ? "Maker" : "Editor")")
                            .font(.dmSans(size: 17, weight: .bold))
                        
                        Button(action: { Task(operation: viewModel.save) }) {
                            Text("Save")
                                .font(.dmSans(size: 17, weight: .bold))
                                .foregroundColor(Color.systemBlack)
                        }
                        .alignTrailing()
                    }
                HStack {
                    TextField("Name of rule", text: $viewModel.rule.name, axis: .horizontal)
                        .font(.dmSans(size: 20, weight: .regular))
                        .keyboardType(.alphabet)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.return)
                        .focused($focusedField, equals: .name)
                        .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                    Spacer()
                    if viewModel.rule.name.isEmpty {
                        Button(action: {
                            if let clipboard = UIPasteboard.general.string {
                                viewModel.rule.name = clipboard
                            } else {
                                Haptics.fire(.error)
                            }
                        }) {
                            Image(systemName: "clipboard").bold()
                        }
                    }
                }
                .modifier(BorderedTextFieldModifier(isActive: focusedField == .name))
                
                HStack {
                    TextField("Description of rule", text: $viewModel.rule.description, axis: .vertical)
                        .font(.dmSans(size: 20, weight: .regular))
                        .keyboardType(.alphabet)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.return)
                        .focused($focusedField, equals: .description)
                        .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                    
                        Spacer()
                    
                        if viewModel.rule.description.isEmpty {
                            Button(action: {
                                if let clipboard = UIPasteboard.general.string {
                                    viewModel.rule.description = clipboard
                                    Haptics.fire(.light)
                                } else {
                                    Haptics.fire(.error)
                                }
                            }) {
                                Image(systemName: "clipboard").bold()
                            }
                        }
                    }
                    .modifier(BorderedTextFieldModifier(isActive: focusedField == .description))
                    
                    HStack(spacing: 20) {
                        if viewModel.rule.icon.count == 4 {
                            AwesomeImage(
                                rawIcon: viewModel.rule.icon.unicode ?? "",
                                style: .regular,
                                size: 20,
                                color: .systemBlack)
                            
                            Rectangle()
                                .fill(Color.systemGray4)
                                .frame(width: 1, height: 24)
                        }
                        
                        TextField("Icon (####)", text: $viewModel.rule.icon, axis: .horizontal)
                            .font(.dmSans(size: 20, weight: .regular))
                            .keyboardType(.alphabet)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.return)
                            .focused($focusedField, equals: .icon)
                            .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                        if viewModel.rule.icon.isEmpty {
                            Button(action: {
                                if let clipboard = UIPasteboard.general.string {
                                    viewModel.rule.icon = clipboard
                                    Haptics.fire(.light)
                                } else {
                                    Haptics.fire(.error)
                                }
                            }) {
                                Image(systemName: "clipboard").bold()
                            }
                        }
                    }
                    .modifier(BorderedTextFieldModifier(isActive: focusedField == .icon))
                    
                    HStack(spacing: 20) {
                        Text("Type:")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                            .frame(width: 60)
                        selectionButton(
                            label: "Team",
                            isSelected: viewModel.rule.type == RuleType.team.rawValue,
                            onTap: { viewModel.rule.type = RuleType.team.rawValue })
                        selectionButton(
                            label: "Player",
                            isSelected: viewModel.rule.type == RuleType.player.rawValue,
                            onTap: { viewModel.rule.type = RuleType.player.rawValue })
                    }
                    
                    HStack(spacing: 20) {
                        Text("Level:")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                            .frame(width: 60)
                        selectionButton(
                            label: "Easy",
                            isSelected: viewModel.rule.difficulty == RuleDifficulty.favor.rawValue,
                            onTap: { viewModel.rule.difficulty = RuleDifficulty.favor.rawValue })
                        selectionButton(
                            label: "Hard",
                            isSelected: viewModel.rule.difficulty == RuleDifficulty.challenge.rawValue,
                            onTap: { viewModel.rule.difficulty = RuleDifficulty.challenge.rawValue })
                    }
                    
                    HStack(spacing: 20) {
                        Text("Par:")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                            .frame(width: 60)
                        selectionButton(
                            label: "3",
                            isSelected: viewModel.rule.par.contains(HolePar.three.rawValue),
                            onTap: { viewModel.rule.par.toggle(HolePar.three.rawValue) })
                        selectionButton(
                            label: "4",
                            isSelected: viewModel.rule.par.contains(HolePar.four.rawValue),
                            onTap: { viewModel.rule.par.toggle(HolePar.four.rawValue) })
                        selectionButton(
                            label: "5",
                            isSelected: viewModel.rule.par.contains(HolePar.five.rawValue),
                            onTap: { viewModel.rule.par.toggle(HolePar.five.rawValue) })
                    }
                    
                    HStack(spacing: 20) {
                        Text("Hole:")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                            .frame(width: 60)
                        VStack {
                            selectionButton(
                                label: "Water",
                                isSelected: viewModel.rule.conditions.contains(HoleCondition.water.rawValue),
                                onTap: { viewModel.rule.conditions.toggle(HoleCondition.water.rawValue) })
                            selectionButton(
                                label: "Trees",
                                isSelected: viewModel.rule.conditions.contains(HoleCondition.trees.rawValue),
                                onTap: { viewModel.rule.conditions.toggle(HoleCondition.trees.rawValue) })
                        }
                        VStack {
                            selectionButton(
                                label: "Bunkers",
                                isSelected: viewModel.rule.conditions.contains(HoleCondition.bunkers.rawValue),
                                onTap: { viewModel.rule.conditions.toggle(HoleCondition.bunkers.rawValue) })

                            selectionButton(
                                label: "Wind",
                                isSelected: viewModel.rule.conditions.contains(HoleCondition.wind.rawValue),
                                onTap: { viewModel.rule.conditions.toggle(HoleCondition.wind.rawValue) })
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: focusedField, perform: { focus in
            if focus != nil {
                Haptics.fire(.light)
            }
        })
    }
    
    private func selectionButton(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.fire(.light)
            onTap()
        }) {
            VStack {
                Text(label)
                    .frame(height: 40)
                    .font(.dmSans(size: 17, weight: .medium))
                    .foregroundColor(isSelected ? Color.systemBlack : Color.systemGray2)
                    .alignCenter()
                    .background(Color.clear)
                    .border(
                        isSelected ? Color.systemBlack : Color.systemGray4, width: isSelected ? 4 : 2, cornerRadius: 10
                    )
                    .cornerRadius(10)
            }
        }
    }
}

struct ChaosRuleEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ChaosRuleEditorView(viewModel: ChaosEditorViewModel())
            .holisticPreview()
    }
}
