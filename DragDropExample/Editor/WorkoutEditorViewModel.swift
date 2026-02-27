//
//  WorkoutEditorViewModel.swift
//  BoxFox
//
//  Created by Kyle Beard on 2/12/23.
//

import Foundation
import SwiftUI
import UIKit

enum WorkoutToolbarType {
    /// [Name generator?] [Pattern or rep scheme?] ... [up] [down] [+]
    case name
    
    /// [tip?] [suggestive] ... [up] [down] [+]
    case title
    
    // [tip?] [auto-fill suggestions] ... [up] [down] [+]
    case movement
    
    // [tip?] ... [up] [down] [+]
    case caption
    
    // ... [up] [down] [+]
    case none
}

@MainActor
class WorkoutEditorViewModel: Boxable {
    @Published var workout: Workout = Workout()
    @Published var toolbarType: WorkoutToolbarType = .name
    
    /// Workout title
    @Published var name: String = ""
    @Published var workoutType: WorkoutType = .none
    @Published var scoringType: ScoringType = .none
    @Published var metadata: WorkoutMetadata = WorkoutMetadata()
    @Published var nameWasFocused: Bool = false
    
    /// Workout body
    @Published var rows: [WorkoutRow] = [WorkoutRow(type: WorkoutRowType.title.rawValue)]
    @Published var rowFocus: [Bool] = [false]
    @Published var focusedIndex: Int = -1
    @Published var isFocused: Bool = false
    
    // Drag and drop
    @Published var dragItem: String?
    @Published var isDragging: Bool = false
    
    @Published var isSaving: Bool = false
    @Published var isEditing: Bool = false
    
    init() { print("init WorkoutEditorViewModel") }
    deinit { print("deinit WorkoutEditorViewModel") }
    
    // MARK: - Load
    
    func load(_ w: Workout) {
        name = w.name
        workoutType = WorkoutType(rawValue: w.type) ?? .none
        scoringType = ScoringType(rawValue: w.scoring) ?? .none
        rows = w.rows
        metadata = w.metadata
        
        nameWasFocused = !name.isEmpty
    }
    
    // MARK: - Editing
    
    func addNewRow() {
        withAnimation(.linear(duration: 0.175)) {
            rows.append(WorkoutRow(type: WorkoutRowType.movement.rawValue))
        }
    }
    
    func copyRow(for index: Int) {
        print(#function)
        rows.append(rows[index])
    }
    
    func removeRow(for index: Int) {
        print(#function)
        if focusedIndex == index {
            /// Removing at current active index
            focusedIndex -= 1
        } else {
            /// Removing at another index
        }
        rows.remove(at: index)
    }
    
    // MARK: - Save
    
    @Sendable func save() async {
        isSaving = true
        defer { isSaving = false }
        
        let w = buildWorkout()
        
        print(#function)
        printPretty(rows)
        // TODO: let w = try await isEditing ? workout.put() : workout.post()
    }
    
    private func buildWorkout() -> Workout {
        return Workout()
    }
}
