//
//  String.swift
//  Hackers
//
//  Created by Kyle Beard on 11/14/22.
//

import Foundation

extension String {
//    func fromHex() -> String? {
//        return "&#x\(self);".applyingTransform(.toXMLHex, reverse: true)
//    }
    
    var unicode: String? {
        if let charCode = UInt32(self, radix: 16), let unicode = UnicodeScalar(charCode) {
            let str = String(unicode)
            return String(unicode)
        }
        return nil
    }
    
    var unicodeEscaped: String? {
        return self.flatMap(\.unicodeScalars).compactMap({ $0.escaped(asASCII: true) }).first
    }
}
