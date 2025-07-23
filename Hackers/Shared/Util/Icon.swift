//
//  Icon.swift
//  Hackers
//
//  Created by Kyle Beard on 7/10/25.
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
        /// Apple logo from FA-brands
        Icon(name: "f179", size: 32, weight: .brand)
            .foregroundStyle(Color.red)
        /// Magnifying glass from FA-thin
        Icon(name: "f002", size: 32, weight: .thin)
            .foregroundStyle(Color.orange)
        /// Magnifying glass from FA-light
        Icon(name: "f002", size: 32, weight: .light)
            .foregroundStyle(Color.yellow)
        /// Magnifying glass from FA-regular
        Icon(name: "f002", size: 32, weight: .regular)
            .foregroundStyle(Color.green)
        /// Magnifying glass from FA-solid
        Icon(name: "f002", size: 32, weight: .solid)
            .foregroundStyle(Color.blue)
        /// Magnifying glass from SF
        Icon(name: "magnifyingglass", size: 32, weight: .regular)
            .foregroundStyle(Color.indigo)
        /// [?] box for not found
        Icon(name: "xyz", size: 32, weight: .regular)
            .foregroundStyle(Color.purple)
    }
}
