//
//  ClearTextButton.swift
//  Hackers
//
//  Created by Kyle Beard on 11/13/25.
//

import SwiftUI

struct ClearTextButton: View {
    var theme: PaletteTheme = .primary
    var onTap: Callback? = nil
    
    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap?()
        }) {
            Icon(name: "f00d", size: 11, maxSize: 11, weight: .solid)
                .foregroundStyle(Color.neutral)
                .frame(width: 18, height: 18)
                .background(Color.neutral5)
                .clipShape(Circle())
        }
    }
}

#Preview {
    VStack {
        ClearTextButton()
        Spacer()
    }
    .padding(20)
    .background(Color.backgroundPrimary)
}
