//
//  BackButton.swift
//  Hackers
//
//  Created by Kyle Beard on 10/24/22.
//

import SwiftUI

struct BackButton: View {
    var icon: Awesome = .arrowLeftLong
    var style: AwesomeFont = .solid
    var onTap: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
            Haptics.fire(.light)
        }) {
            AwesomeImage(icon: icon, style: style, size: 24, color: .systemBlack)
        }
    }
}
