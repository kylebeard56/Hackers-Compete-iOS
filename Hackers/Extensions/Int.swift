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
    
    var toGolfScore: String {
        if self > 0 {
            return "+\(self)"
        } else if self < 0 {
            return "\(self)"
        } else {
            return "E"
        }
    }
    
    var toGolfColor: Color {
        if self > 0 {
            return .systemBlack
        } else if self < 0 {
            return .systemRed
        } else {
            return .systemGreen
        }
    }
    
    var toGolfColorInverted: Color {
        if self > 0 {
            return .systemWhite
        } else if self < 0 {
            return .systemRed
        } else {
            return .systemGreen
        }
    }
    
    var numericalSuffix: String {
        switch self {
        case 1:         return "st"
        case 2:         return "nd"
        case 3:         return "rd"
        default:        return "th"
        }
    }
}
