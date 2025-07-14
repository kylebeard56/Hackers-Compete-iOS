//
//  Logo.swift
//  Hackers
//
//  Created by Kyle Beard on 7/11/25.
//

import SwiftUI

struct Logo: View {
    var body: some View {
        Image("LogoGreen")
            .interpolation(.high)
            .resizable()
            .scaledToFit()
    }
}
