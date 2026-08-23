//
//  Navigation.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import UIKit
import SwiftUI

// [Oct 2021 | iOS 15.1+] This fixes the swipe-to-return gesture within a NavigationView when using custom back button.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

extension View {
    func disableSwipeBack() -> some View {
        self.background(DisableSwipeBackView())
    }
}

struct DisableSwipeBackView: UIViewControllerRepresentable {
    typealias UIViewControllerType = DisableSwipeBackViewController
    func makeUIViewController(context: Context) -> UIViewControllerType { UIViewControllerType() }
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) { }
}

class DisableSwipeBackViewController: UIViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if let parent = parent?.parent,
           let navigationController = parent.navigationController,
           let interactivePopGestureRecognizer = navigationController.interactivePopGestureRecognizer {
            navigationController.view.removeGestureRecognizer(interactivePopGestureRecognizer)
        }
    }
}
