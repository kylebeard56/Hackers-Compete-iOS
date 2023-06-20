//
//  Callbacks.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/23.
//

import Foundation
import SwiftUI

typealias OnTap = () -> Void
typealias OnTapAync = () async -> Void
typealias OnItem = (Any) -> Void
typealias OnItemAsync = (Any) async -> Void

protocol OnSelectable {
    var onTap: OnTap? { get set }
    var onTapAsync: OnTapAync? { get set }
    var onItem: OnItem? { get set }
    var onItemAsync: OnItemAsync? { get set }
}

extension OnSelectable {
    func triggerOnTap() {
        if let action = onTap {
            Haptics.fire(.light)
            action()
        }
    }
    
    func triggerOnTapAsync() async {
        if let action = onTapAsync {
            Haptics.fire(.light)
            await action()
        }
    }
    
    func triggerOnItem(_ item: Any) {
        if let action = onItem {
            Haptics.fire(.light)
            action(item)
        }
    }
    
    func triggerOnItemAsync(_ item: Any) async {
        if let action = onItemAsync {
            Haptics.fire(.light)
            await action(item)
        }
    }
    
    func onTap(perform action: @escaping () -> Void) -> Self {
        var a = self
        a.onTap = action
        return a
    }
    
    func onTapAsync(perform action: @escaping () async -> Void) -> Self {
        var a = self
        a.onTapAsync = action
        return a
    }
    
    func onItem(perform action: @escaping (Any) -> Void) -> Self {
        var a = self
        a.onItem = action
        return a
    }
    
    func onItemAsync(perform action: @escaping (Any) async -> Void) -> Self {
        var a = self
        a.onItemAsync = action
        return a
    }
}
