//
//  Async.swift
//  Hackers
//
//  Created by Kyle Beard on 11/13/25.
//

import Foundation

/// Runs a closure on the main queue after a delay in seconds.
func asyncAfter(_ delay: TimeInterval, execute: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: execute)
}
