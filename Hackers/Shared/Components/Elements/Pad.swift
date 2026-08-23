//
//  Pad.swift
//  Hackers
//
//  Created by Kyle Beard on 2/2/26.
//

import SwiftUI

struct Padding: View {
    let value: CGFloat
    let axis: Axis.Set
    
    init(_ axis: Axis.Set, _ value: CGFloat) {
        self.axis = axis
        self.value = value
    }
    
    var body: some View {
        Group {
            if axis == .horizontal {
                Spacer(minLength: 0)
                    .frame(width: value)
            }
            if axis == .vertical {
                Spacer(minLength: 0)
                    .frame(height: value)
            }
        }
    }
}
