//
//  QueryFunctions.swift
//  Hackers
//
//  Created by Kyle Beard on 6/22/23.
//

import SwiftUI

/// Documentation: https://www.swiftbysundell.com/articles/custom-query-functions-using-key-paths/

/**
 Example of cool sorting:
 
 struct Person {
   var name: String
   var age: Int
 }

 let unsorted = [
   Person(name: "Alice", age: 20),
   Person(name: "Bob", age: 21),
   Person(name: "Alice", age: 30),
   Person(name: "Bob", age: 31),
 ]

 let sorted = unsorted.sorted(using: [
   KeyPathComparator(\.name),
   KeyPathComparator(\.age, order: .reverse)
 ])
 // Returns: Alice/30, Alice/20, Bob/31, Bob/21
 */

extension Int {
    var isFrontNine: Bool { self <= 9 }
    var isBackNine: Bool { self >= 10 }
}
