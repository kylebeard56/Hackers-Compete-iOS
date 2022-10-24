//
//  Navigation.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import Foundation
import UIKit

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
