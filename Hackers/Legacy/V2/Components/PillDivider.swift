//
//  PillDivider.swift
//  Hackers
//
//  Created by Kyle Beard on 1/29/23.
//

import SwiftUI

struct PillDivider: View {
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(colorScheme == .light ? Color.systemGray5 : Color.systemGray3)
            .frame(width: 80, height: 2, alignment: .center)
    }
}
