//
//  Pretty.swift
//  Hackers
//
//  Created by Kyle Beard on 11/15/22.
//

import Foundation
import SwiftPrettyPrint

/// If not in Admin mode, we want to limit prints to preserve performance.

public func print(_ object: Any...) {
    //#if DEBUG
    if !adminMode { return }
    for item in object {
        Swift.print(item)
    }
    //#endif
}

public func print(_ object: Any) {
    //#if DEBUG
    if !adminMode { return }
    Swift.print(object)
    //#endif
}

func printPretty(_ a: Any) {
    //#if DEBUG
    if !adminMode { return }
    Pretty.prettyPrint(a)
    //#endif
}
