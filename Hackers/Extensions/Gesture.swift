//
//  Gesture.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

extension DragGesture.Value {
    var isDraggingUp: Bool {
        self.translation.height < 0
    }

    var isDraggingDown: Bool {
        self.translation.height > 0
    }

    var isDraggingLeft: Bool {
        self.translation.width < 0
    }

    var isDraggingRight: Bool {
        self.translation.width > 0
    }

    var isDraggingRightSignificantly: Bool {
        self.translation.width > 40
    }
}
