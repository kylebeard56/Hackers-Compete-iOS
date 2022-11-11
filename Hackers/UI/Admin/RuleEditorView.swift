//
//  RuleEditorView.swift
//  Hackers
//
//  Created by Kyle Beard on 11/10/22.
//

import AlertToast
import SwiftUI

struct RuleEditorView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = RuleEditorViewModel()
    
    var rule: Rule = Rule()
    
    @State private var showVerifyIcon: Bool = false
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case name, description, icon }
    
    var body: some View {
        ZStack {
            ScrollView {
                content
            }
            
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
            .padding(.horizontal, kPadding)
            .padding(.vertical, kPadding / 2)
            .alignBottom()
            .ignoresSafeArea(.keyboard)
        }
        .resignKeyboardOnTapGesture()
        .resignKeyboardOnDragGesture()
        .background(Color.systemViewBackground)
        .onAppear() { viewModel.load(rule) }
        .onChange(of: viewModel.didSave, perform: { value in
            if value {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: {
                    dismiss()
                })
            }
        })
        .toast(isPresenting: $viewModel.didSave, alert: { AlertToast.successBanner("Rule saved") })
        .toast(isPresenting: $viewModel.didFail, alert: { AlertToast.errorBanner("Couldn't save rule") })
        .toast(isPresenting: $viewModel.didReject, alert: { AlertToast.errorBanner("Rule incomplete") })
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button(action: { UIApplication.shared.endEditing() }) {
                    Text("Done").bold()
                }.alignTrailing()
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: kPadding) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: kPadding) {
                    ZStack {
                        Text("Rule \(rule.id.isEmpty ? "Maker" : "Editor")")
                            .font(.dmSans(size: 17, weight: .bold))
                        BackButton(icon: .xmark, onTap: { dismiss() })
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
                        .modifier(BorderedTextFieldModifier(isActive: focusedField == .name))
                    Spacer()
                    if viewModel.rule.name.isEmpty {
                        Button(action: {
                            if let clipboard = UIPasteboard.general.string {
                                viewModel.rule.name = clipboard
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
                                }
                            }) {
                                Image(systemName: "clipboard").bold()
                            }
                        }
                    }
                    .modifier(BorderedTextFieldModifier(isActive: focusedField == .description))
                    
                    HStack {
                        TextField("Icon", text: $viewModel.rule.icon, axis: .horizontal)
                            .font(.dmSans(size: 20, weight: .regular))
                            .keyboardType(.alphabet)
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.return)
                            .focused($focusedField, equals: .icon)
                            .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                        Spacer()
                        if viewModel.rule.icon.isEmpty {
                            Button(action: {
                                if let clipboard = UIPasteboard.general.string {
                                    viewModel.rule.icon = clipboard
                                }
                            }) {
                                Image(systemName: "clipboard").bold()
                            }
                        }
                    }
                    .modifier(BorderedTextFieldModifier(isActive: focusedField == .icon))
                    
                    HStack(spacing: kPadding) {
                        Text("Pack:")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                            .frame(width: 60)
                        selectionButton(
                            label: "Gameplay",
                            isSelected: viewModel.rule.packID == PackName.gameplay.rawValue,
                            onTap: { viewModel.setPack(id: PackName.gameplay.rawValue) })
                        selectionButton(
                            label: "Drinking",
                            isSelected: viewModel.rule.packID == PackName.drinking.rawValue,
                            onTap: { viewModel.setPack(id: PackName.drinking.rawValue) })
                    }
                    .padding(.top, kPadding)
                    
                    HStack(spacing: kPadding) {
                        Text("Level:")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                            .frame(width: 60)
                        selectionButton(
                            label: "Easy",
                            isSelected: viewModel.rule.difficulty == RuleDifficulty.easy.rawValue,
                            onTap: { viewModel.rule.difficulty = RuleDifficulty.easy.rawValue })
                        selectionButton(
                            label: "Hard",
                            isSelected: viewModel.rule.difficulty == RuleDifficulty.hard.rawValue,
                            onTap: { viewModel.rule.difficulty = RuleDifficulty.hard.rawValue })
                    }
                    
                    if viewModel.rule.packID == PackName.gameplay.rawValue {
                        HStack(spacing: kPadding) {
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
                    }
                    
                    if viewModel.rule.packID == PackName.drinking.rawValue {
                        HStack(spacing: kPadding) {
                            Text("Type:")
                                .font(.dmSans(size: 17, weight: .medium))
                                .foregroundColor(Color.systemBlack)
                                .alignLeading()
                                .frame(width: 60)
                            selectionButton(
                                label: "Round",
                                isSelected: viewModel.rule.type == RuleType.round.rawValue,
                                onTap: { viewModel.rule.type = RuleType.round.rawValue })
                            selectionButton(
                                label: "Hole",
                                isSelected: viewModel.rule.type == RuleType.hole.rawValue,
                                onTap: { viewModel.rule.type = RuleType.hole.rawValue })
                        }
                    }
                }
            }
            .padding(.horizontal, kPadding)
        }
    }
    
    private func selectionButton(label: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
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

struct RuleEditorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                RuleEditorView()
            }
            .lightModePreview()
            
            NavigationStack {
                RuleEditorView()
            }
            .darkModePreview()
        }
    }
}
