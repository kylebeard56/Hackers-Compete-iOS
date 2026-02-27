//
//  RowDropDelegate.swift
//  BoxFox
//
//  Created by Kyle Beard on 3/22/23.
//

import SwiftUI

struct RowDropDelegate: DropDelegate {
    let currentItem: String
    var viewModel: WorkoutEditorViewModel

    func performDrop(info: DropInfo) -> Bool {
        viewModel.isDragging = false
        viewModel.dragItem = nil
        return true
    }
    
    // Remove the + sign from top corner of draggable overlay
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        viewModel.isDragging = false
    }
    
    func dropEntered(info: DropInfo) {
        viewModel.isDragging = true
        guard let item = viewModel.dragItem else { return }
        
        if item != currentItem {
            guard let from = viewModel.rows.firstIndex(where: { $0.id == item }),
                  let to = viewModel.rows.firstIndex(where: { $0.id == currentItem })
            else { return }
            
            Haptics.fire(.light)
            viewModel.rows.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
}
