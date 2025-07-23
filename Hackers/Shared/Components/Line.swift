//
//  Line.swift
//  Hackers
//
//  Created by Kyle Beard on 7/20/25.
//

import SwiftUI

struct Line: View {
    var color: Color
    var radius: CGFloat
    var height: CGFloat
    var width: CGFloat
    var axis: Axis
    
    init(
        color: Color = .hackersGray5,
        radius: CGFloat = 2,
        height: CGFloat = 1,
        width: CGFloat = 1,
        _ axis: Axis = .horizontal
    ) {
        self.color = color
        self.radius = radius
        self.height = height
        self.width = width
        self.axis = axis
    }
    
    var body: some View {
        Group {
            if axis == .horizontal {
                RoundedRectangle(cornerRadius: radius)
                    .foregroundStyle(color)
                    .frame(height: height)
            }
            if axis == .vertical {
                RoundedRectangle(cornerRadius: radius)
                    .foregroundStyle(color)
                    .frame(width: width)
            }
        }
    }
}

#Preview {
    VStack {
        Line(.horizontal)
        Line(.vertical)
    }
    
}
