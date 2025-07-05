//
//  Tappable.swift
//  Hackers
//
//  Created by Kyle Beard on 5/1/23.
//

import Foundation

protocol Tappable {
    var onTap: (() -> Void)? { get set }
    var onTapTask: (() async -> Void)? { get set }
}

extension Tappable {
    func triggerOnTap() {
        if let action = self.onTap {
            action()
        }
    }
    
    func onTap(perform action: @escaping () -> Void) -> Self {
        var c = self
        c.onTap = action
        return c
    }
    
    func triggerTaskOnTap() async {
        if let action = self.onTapTask {
            await action()
        }
    }
    
    func onTapTask(perform action: @escaping () async -> Void) -> Self {
        var c = self
        c.onTapTask = action
        return c
    }
}
