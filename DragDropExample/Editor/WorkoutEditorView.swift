//
//  WorkoutEditorView.swift
//  BoxFox
//
//  Created by Kyle Beard on 2/12/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct WorkoutEditorView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel = WorkoutEditorViewModel()
    
    @FocusState private var focus: String?
    @State private var showWorkoutTypeSelector: Bool = false
    @State private var showScoringTypeSelector: Bool = false
    @State private var showAuthPopup: Bool = false
    
    private let rowAnimation: CGFloat = 0.175
    private let headerHeight: CGFloat = 56.0
    @State private var scrollOffset: CGFloat = 0.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                content
                    .padding(.horizontal, 16)
                    .alignTop()
                
                header
                    .frame(height: headerHeight)
                    .background(
                        Blur(style: colorScheme.isLight ? .light : .dark)
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                            .opacity(scrollOffset < -8 ? 1 : 0)
                    )
                    .edgesIgnoringSafeArea(.top)
                    .alignTop()

                BigButton(
                    title: "Create",
                    labelColor: .systemWhite,
                    buttonColor: .systemFox,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { showAuthPopup = true } //Task(operation: viewModel.save) }
                )
                .alignBottom()
                .padding(.horizontal, 16)
                .ignoresSafeArea(.keyboard)
                
                if focus != nil {
                    toolbar
                        .padding(.trailing, 16)
                }
            }
            .background(Color.systemGray6)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear() {
            focus = "name"
        }
        .sheet(isPresented: $showWorkoutTypeSelector) {
            WorkoutTypeSelectionView(type: $viewModel.workoutType)
            .presentationDetents([.height(360)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showScoringTypeSelector) {
            WorkoutScoringSelectionView(type: $viewModel.scoringType)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAuthPopup) {
            AuthPopup()
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            
            // TODO: This could turn into a Menu dropdown to convert to a session.
            Text("New workout")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Content
    
    private var content: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 16) {
                    Spacer()
                        .frame(height: headerHeight)
                        .padding(.top, -8)
                    workoutBuilderCard
                    collectionRow
                    Spacer()
                        .frame(height: UIScreen.main.bounds.height / 2)
                }
                .background(ScrollGeometry(name: "workout"))
                .onChange(of: focus, perform: { value in
                    guard let id = value else { return }
                    proxy.scrollTo(id, anchor: .center)
                })
            }
        }
        .coordinateSpace(name: "workout")
        .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in scrollOffset = v })
    }
    
    // MARK: - Workout Card
    
    private var workoutBuilderCard: some View {
        VStack(spacing: 12) {
            HStack {
                workoutType
                
                TextField("Workout name", text: $viewModel.name)
                    .font(.dmSans(size: 24, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .textInputAutocapitalization(.sentences)
                    .keyboardType(.alphabet)
                    .submitLabel(.return)
                    .autocorrectionDisabled()
                    .minimumScaleFactor(0.69)
                    .focused($focus, equals: "name")
                
                Spacer()
            }
            
            Button(action: { showScoringTypeSelector = true }) {
                Text(viewModel.scoringType.buttonLabel)
                    .font(.dmSans(size: 13, weight: .medium))
                    .foregroundColor(viewModel.scoringType == .none ? Color.systemGray3 : Color.systemBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.systemIconBackground)
                    .cornerRadius(4)
            }
            .alignLeading()
            
            divider
            
            VStack(spacing: 0) {
                ForEach(0..<viewModel.rows.count, id: \.self) { index in
                    let item = viewModel.rows[index].id
                    RowEditorView(viewModel: viewModel, index: index, focus: $focus)
                        .id(item)
                        .padding(.vertical, 4)
                        .contentShape([.dragPreview], RoundedRectangle(cornerRadius: 8))
                        .overlay(viewModel.dragItem == item && viewModel.isDragging ? Color.systemCard : Color.clear)
                        .onDrag({
                            Haptics.fire(.light)
                            viewModel.dragItem = item
                            return NSItemProvider(item: nil, typeIdentifier: item)
                        })
                        .onDrop(of: [.text], delegate: RowDropDelegate(currentItem: item, viewModel: viewModel))
                }
            }
        }
        .padding(16)
        .background(Color.systemCard.resignKeyboardOnTapGesture())
        .cornerRadius(10)
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 16) {
            Spacer(minLength: 0)
            
            // Workout type and scoring buttons
            if focus == "name" {
                if let system = viewModel.workoutType.icon.system {
                    KeyboardFloatingButton(
                        systemIcon: system,
                        tint: viewModel.workoutType.color,
                        onTap: { showWorkoutTypeSelector = true }
                    )
                } else if let awesome = viewModel.workoutType.icon.awesome {
                    KeyboardFloatingButton(
                        awesomeIcon: awesome,
                        tint: viewModel.workoutType.color,
                        onTap: { showWorkoutTypeSelector = true }
                    )
                }
                KeyboardFloatingButton(
                    systemIcon: "timer",
                    tint: .systemBlack,
                    onTap: { showScoringTypeSelector = true }
                )
            }
            
            if let r = viewModel.rows.first(where: { $0.id == focus }), let t = WorkoutRowType(rawValue: r.type) {
                KeyboardFloatingButton(
                    systemIcon: t.icon,
                    tint: .systemBlack,
                    rotation: t.rotation,
                    onTap: toggleRowType
                )
            }
            
            KeyboardFloatingButton(
                systemIcon: "chevron.up",
                tint: focus == "name" ? .systemGray : .systemBlue,
                onTap: previousTapped
            )
            
            KeyboardFloatingButton(
                systemIcon: "chevron.down",
                tint: .systemBlue,
                onTap: nextTapped
            )
            
            KeyboardFloatingButton(
                systemIcon: "plus",
                tint: .white,
                background: .systemFox,
                onTap: addTapped
            )
        }
    }
    
    private func nextTapped() {
        if focus == "name" {
            focus = viewModel.rows.first?.id
        } else {
            if let i = viewModel.rows.firstIndex(where: { $0.id == focus }) {
                if i == viewModel.rows.count - 1 {
                    addTapped()
                } else {
                    focus = viewModel.rows[safe: i + 1]?.id
                    print("next from intermediate row")
                }
            }
        }
    }
    
    private func previousTapped() {
        if focus == "name" {
            focus = nil
            return
        }
        
        if let i = viewModel.rows.firstIndex(where: { $0.id == focus }) {
            if i == 0 {
                focus = "name"
            } else {
                focus = viewModel.rows[safe: i - 1]?.id
            }
        }
    }
    
    private func addTapped() {
        if let i = viewModel.rows.firstIndex(where: { $0.id == focus }) {
            withAnimation(.linear(duration: rowAnimation)) {
                let r = WorkoutRow(type: WorkoutRowType.movement.rawValue)
                if i == viewModel.rows.count - 1 {
                    // This will append to the end
                    viewModel.rows.append(r)
                    focus = r.id
                } else {
                    // This will insert
                    viewModel.rows.insert(r, at: i + 1)
                    focus = r.id
                }
            }
        }
    }
    
    private func toggleRowType() {
        if let r = viewModel.rows.first(where: { $0.id == focus }) {
            let t = WorkoutRowType(rawValue: r.type) ?? .none
            if let i = viewModel.rows.firstIndex(of: r) {
                if t == .title {
                    viewModel.rows[i].type = WorkoutRowType.movement.rawValue
                } else if t == .movement {
                    viewModel.rows[i].type = WorkoutRowType.caption.rawValue
                } else if t == .caption {
                    viewModel.rows[i].type = WorkoutRowType.divider.rawValue
                } else if t == .divider {
                    viewModel.rows[i].type = WorkoutRowType.title.rawValue
                }
            }
        }
    }
    
    // MARK: - Collection
    
    private var collectionRow: some View {
        Button(action: { print("todo: show list popup with collections to checkmark or add new") }) {
            HStack {
                Text("Organize in your collections")
                    .font(.dmSans(size: 17, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                Spacer()
                AwesomeImage(icon: .plus, style: .solid, size: 15, color: .systemFox)
            }
            .padding(16)
            .background(Color.systemCard)
            .cornerRadius(10)
        }
    }
    
    // MARK: - View Components
    
    private var divider: some View {
        Rectangle()
            .fill(Color.systemGray6)
            .frame(height: 1)
    }
    
    private var workoutType: some View {
        Button(action: { showWorkoutTypeSelector = true }) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.systemIconBackground)
                    .frame(width: 36, height: 36)
                
                if viewModel.workoutType == .none {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 15))
                        .foregroundColor(Color.systemGray3)
                } else {
                    if let i = viewModel.workoutType.icon.awesome {
                        AwesomeImage(icon: i, style: .regular, size: 17, color: viewModel.workoutType.color)
                    }
                    if let i = viewModel.workoutType.icon.system {
                        Image(systemName: i)
                            .font(.dmSans(size: 17, weight: .regular))
                            .foregroundColor(viewModel.workoutType.color)
                    }
                }
            }
        }
    }
}

struct WorkoutEditorView_Previews: PreviewProvider {
    static var view: some View {
        WorkoutEditorView().environmentObject(AppSession())
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.notchDevicePreview()
            view.smallDevicePreview()
        }
    }
}
