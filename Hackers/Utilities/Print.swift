//
//  Pretty.swift
//  Hackers
//
//  Created by Kyle Beard on 11/15/22.
//

import Foundation
import LocalConsole
import SwiftPrettyPrint

public func print(_ object: Any...) {
    //#if DEBUG
    for item in object {
        Swift.print(item)
        localConsole.print(item)
    }
    //#endif
}

public func print(_ object: Any) {
    //#if DEBUG
    Swift.print(object)
    localConsole.print(object)
    //#endif
}

func printPretty(_ a: Any) {
    localConsole.print(a)
    Pretty.prettyPrint(a)
}
