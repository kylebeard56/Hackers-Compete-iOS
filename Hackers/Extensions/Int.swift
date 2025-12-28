//
//  Int.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/23.
//

import SwiftUI

extension Int {
    /// Reduce a Text string value to a smaller size if it won't fit
    func squeeze( _ text: String, into width: CGFloat, for weight: CustomFontWeight) -> CGFloat {
        var size = CGFloat(self)
        let font = UIFont.dmSans(size: size, weight: weight)
        
        //if text.width(usingFont: font) <= width { return size }
        repeat {
            size -= 1
            
        } while text.width(usingFont: font) > width
        return size
    }
}
