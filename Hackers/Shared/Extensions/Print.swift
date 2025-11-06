//
//  Print.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
//

import Foundation
import SwiftPrettyPrint

public func print(_ object: Any...) {
#if SANDBOX
    for item in object {
        Swift.print(item)
//        Task { await localConsole.print(item) }
    }
#endif
}

public func print(_ object: Any) {
#if SANDBOX
    Swift.print(object)
//    Task { await localConsole.print(object) }
#endif
}

public func printPretty(_ a: Any) {
#if SANDBOX
    Pretty.prettyPrint(a)
//    Task { await localConsole.print(a) }
#endif
}
