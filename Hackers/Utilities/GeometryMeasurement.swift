//
//  GeometryMeasurement.swift
//  Hackers
//
//  Created by Kyle Beard on 7/4/24.
//

import Foundation
import SwiftUI

enum GeometryMeasurementType {
    case height, width
}

struct GeometryMeasurement: ViewModifier {
    var dimension: GeometryMeasurementType
    @Binding var value: CGFloat
    
    init(_ dimension: GeometryMeasurementType, value: CGFloat) {
        self.dimension = dimension
        self.value = value
    }
    
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geom -> Color in
                DispatchQueue.main.async {
                    switch dimension {
                    case .height:   value = geom.size.height
                    case .width:    value = geom.size.width
                    }
                }
                return Color.clear
            }
        )
    }
}
