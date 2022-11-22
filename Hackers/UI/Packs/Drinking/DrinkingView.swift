//
//  DrinkingView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/26/22.
//

import SwiftUI

struct DrinkingView: View {
    var body: some View {
        VStack(spacing: kPadding) {
            Spacer()
            Text("Coming Soon")
                .foregroundStyle(kDrinkingPack.style.linearGradient)
                .font(.dmSans(size: 32, weight: .medium))
                .alignCenter()
            Spacer()
        }
        .border(Color.systemGray5, width: 2, cornerRadius: 20)
        .padding(kPadding)
    }
}

struct DrinkingView_Previews: PreviewProvider {
    static var previews: some View {
        DrinkingView()
    }
}
