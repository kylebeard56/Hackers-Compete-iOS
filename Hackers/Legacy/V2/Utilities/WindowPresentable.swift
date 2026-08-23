//
//  WindowPresentable.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/23.
//

import SwiftUI

protocol WindowPresentable {}

extension WindowPresentable {
    func presentOnWindow<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        if let view = UIHostingController(rootView: content()).view {
            view.backgroundColor = .black.withAlphaComponent(0.2)
            HackersNotification.presentOnWindow.send(with: view)
        }
    }
    
    func clearPresentedWindow() {
        HackersNotification.clearWindowPresentable.send()
    }
}
