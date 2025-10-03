//
//  Dot.swift
//  Hackers
//
//  Created by Kyle Beard on 8/11/25.
//

import SwiftUI

struct Dot: View {
    var color = Color.neutral3
    var size = 2.5
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
