//
//  Icon.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/24.
//  Copyright © 2024 Tiger Mind Labs, Inc. All rights reserved.
//

import SwiftUI

struct Icon: View {
    @Environment(\.legibilityWeight) var legibilityWeight
    
    /// Four character unicode from https://fontawesome.com/search (i.e. f002) or the name of the SF Symbol
    var name: String
    
    /// Default is 20
    var size: CGFloat
    
    // Default is nil
    var maxSize: CGFloat?
    
    /// Default is regular
    var weight: FontModule.Weight
    
    init(
        name: String,
        size: CGFloat = 20,
        maxSize: CGFloat? = nil,
        weight: FontModule.Weight = .regular
    ) {
        self.name = name
        self.size = size
        self.maxSize = maxSize
        self.weight = weight
    }

    var body: some View {
        HStack {
            if let _ = UIImage(systemName: name) {
                /// SF Symbol
                Image(systemName: name)
                    .font(.system, size: size, maxSize: maxSize, weight: weight)
            } else if let icon = name.unicode {
                /// Awesome Icon
                Text(icon)
                    .font(.awesome, size: size, maxSize: maxSize, weight: weight)
            } else {
                /// Fallthrough
                Image(systemName: "questionmark.app")
                    .font(.system, size: size, maxSize: maxSize, weight: weight)
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        Icon(name: "f002", size: 32, weight: .regular)
            .foregroundStyle(Color.red)
        Icon(name: "magnifyingglass", size: 32, weight: .regular)
            .foregroundStyle(Color.green)
        Icon(name: "xyz", size: 32, weight: .regular)
            .foregroundStyle(Color.blue)
    }
}
