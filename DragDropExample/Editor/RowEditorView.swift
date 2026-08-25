//
//  RowEditorView.swift
//  BoxFox
//
//  Created by Kyle Beard on 2/16/23.
//

import SwiftUI

struct RowEditorView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject var viewModel: WorkoutEditorViewModel
    var index: Int
    var focus: FocusState<String?>.Binding

    var onTap: OnCallback?
    
    @State private var row: WorkoutRow = WorkoutRow(type: WorkoutRowType.title.rawValue)
    
    private var accessoryColor: Color {
        colorScheme.isLight ? Color.systemGray5 :  Color.systemGray4
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                editor
                    .opacity(row.type == WorkoutRowType.divider.rawValue ? 0 : 1)
                
                if row.type == WorkoutRowType.divider.rawValue {
                    Rectangle()
                        .fill(focus.wrappedValue == row.id ? Color.systemBlue : Color.systemGray6)
                        .frame(height: 1)
                }
            }

            Spacer(minLength: 0)
            
            menuCircle
        }
        .onAppear() {
            row = viewModel.rows[index]
        }
        .onChange(of: row, perform: { r in
            viewModel.rows[index] = r
        })
        .onChange(of: viewModel.rows, perform: { rows in
            if focus.wrappedValue == nil { return }
            if let r = viewModel.rows.first(where: { $0.id == row.id }) {
                if row.type != r.type {
                    row.type = r.type
                }
            }
        })
    }

    // MARK: - Menu Actions
    
    private func changeRow(to type: WorkoutRowType) {
        print(#function)
        Haptics.fire(.light)
        row.type = type.rawValue
    }
    
    private func copyTapped() {
        print(#function)
        Haptics.fire(.light)
        let r = WorkoutRow(type: row.type, quantity: row.quantity, text: row.text, detail: row.detail)
        viewModel.rows.append(r)
    }
    
    private func removeTapped() {
        print(#function)
        Haptics.fire(.light)
        viewModel.rows.removeAll(where: { $0.id == row.id })
    }
}

// MARK: - Action Icon

extension RowEditorView {
    
    fileprivate var menuCircle: some View {
        Menu {
//            if row.text.isEmpty {
//                Button(action: { changeRow(to: .movement) }) {
//                    Label(WorkoutRowType.movement.name, systemImage: WorkoutRowType.movement.icon)
//                }
//                Button(action: { changeRow(to: .title) }) {
//                    Label(WorkoutRowType.title.name, systemImage: WorkoutRowType.title.icon)
//                }
//                Button(action: { changeRow(to: .caption) }) {
//                    Label(WorkoutRowType.caption.name, systemImage: WorkoutRowType.caption.icon)
//                }
//            } else {
//                Menu("Style") {
//                    Button(action: { changeRow(to: .movement) }) {
//                        Label(WorkoutRowType.movement.name, systemImage: WorkoutRowType.movement.icon)
//                    }
//                    .opacity(row.type == WorkoutRowType.movement.rawValue ? 0 : 1)
//
//                    Button(action: { changeRow(to: .title) }) {
//                        Label(WorkoutRowType.title.name, systemImage: WorkoutRowType.title.icon)
//                    }
//                    .opacity(row.type == WorkoutRowType.title.rawValue ? 0 : 1)
//
//                    Button(action: { changeRow(to: .caption) }) {
//                        Label(WorkoutRowType.caption.name, systemImage: WorkoutRowType.caption.icon)
//                    }
//                    .opacity(row.type == WorkoutRowType.caption.rawValue ? 0 : 1)
//                }
//            }
            
            Button(action: copyTapped) {
                Label("Copy", systemImage: "square.on.square")
            }
            
//            Divider()

            Button(role: .destructive, action: removeTapped) {
                Label("Remove", systemImage: "minus.circle")
            }
        } label: {
            Circle()
                .stroke(accessoryColor, lineWidth: 2)
                .frame(width: 8)
                .padding(8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .onTapGesture {
            Haptics.fire(.light)
        }
    }
}

// MARK: - Editor

extension RowEditorView {
    
    private var placeholder: String {
        switch row.type {
        case WorkoutRowType.movement.rawValue:  return "Movement or exercise"
        case WorkoutRowType.title.rawValue:     return "Title or structure"
        case WorkoutRowType.caption.rawValue:   return "Caption or footnote"
        default:                                return ""
        }
    }
    
    private var fontSize: CGFloat {
        switch row.type {
        case WorkoutRowType.movement.rawValue:  return 17
        case WorkoutRowType.title.rawValue:     return 17
        case WorkoutRowType.caption.rawValue:   return 15
        default:                                return 17
        }
    }
    
    private var fontWeight: CustomFontWeight {
        switch row.type {
        case WorkoutRowType.movement.rawValue:  return .regular
        case WorkoutRowType.title.rawValue:     return .medium
        case WorkoutRowType.caption.rawValue:   return .regular
        default:                                return .medium
        }
    }
    
    private var editorColor: Color {
        switch row.type {
        case WorkoutRowType.movement.rawValue:  return Color.systemFox
        case WorkoutRowType.title.rawValue:     return Color.systemBlack
        case WorkoutRowType.caption.rawValue:   return Color.systemGray
        default:                                return Color.systemBlack
        }
    }
    
    fileprivate var editor: some View {
        TextField(placeholder, text: $row.text)
            .font(.dmSans(size: fontSize, weight: row.text.isEmpty ? .regular : fontWeight))
            .foregroundColor(editorColor)
            .textInputAutocapitalization(.sentences)
            .keyboardType(.alphabet)
            .submitLabel(.return)
            .autocorrectionDisabled()
            .focused(focus, equals: row.id)
//            .tracking(0.25)
            .minimumScaleFactor(0.69)
            .alignLeading()
    }
}

// MARK: - Callbacks
//
//extension RowEditorView {
//
//    fileprivate func callbackOnCommit() {
//        if let onCommit { onCommit() }
//    }
//
//    fileprivate func callbackOnFocus() {
//        if let onFocus { onFocus() }
//    }
//
//    fileprivate func callbackOnRowTypeChange() {
//        if let onRowTypeChange { onRowTypeChange(index) }
//    }
//
//    fileprivate func callbackOnCopy() {
//        if let onCopy { onCopy(index) }
//    }
//
//    fileprivate func callbackOnRemove() {
//        if let onRemove { onRemove(index) }
//    }
//
//    func onCommit(_ action: @escaping OnCallback) -> Self {
//        var c = self
//        c.onCommit = action
//        return c
//    }
//
//    func onFocus(_ action: @escaping OnCallback) -> Self {
//        var c = self
//        c.onFocus = action
//        return c
//    }
//
//    func onRowTypeChange(_ action: @escaping OnIntCallback) -> Self {
//        var c = self
//        c.onRowTypeChange = action
//        return c
//    }
//
//    func onCopy(_ action: @escaping OnIntCallback) -> Self {
//        var c = self
//        c.onCopy = action
//        return c
//    }
//
//    func onRemove(_ action: @escaping OnIntCallback) -> Self {
//        var c = self
//        c.onRemove = action
//        return c
//    }
//}

struct RowEditorView_Previews: PreviewProvider {
    @FocusState static var focus: String?
    static var row: WorkoutRow = WorkoutRow(type: WorkoutRowType.title.rawValue)
    static var view: some View {
        RowEditorView(viewModel: WorkoutEditorViewModel(), index: 0, focus: $focus)
    }
    static var previews: some View {
        ZStack {
            Color.systemGray6
            VStack {
                view
            }
            .padding(16)
            .background(Color.systemCard)
            .cornerRadius(8)
            .padding(16)
        }
    }
}
