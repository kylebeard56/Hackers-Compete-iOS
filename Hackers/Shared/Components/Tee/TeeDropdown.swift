//
//  TeeDropdown.swift
//  Hackers
//
//  Created by Kyle Beard on 9/28/25.
//

import SwiftUI

struct TeeDropdown: View {
    var tee: Tee? = nil
    var segment: HoleSegment = .full18
    var showGender = false
    var showDifficulty = false
    var placeholder = "Select default tee"
    var onTap: Callback? = nil
    
    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            onTap?()
        }) {
            HStack {
                if let tee {
                    TeeRow(tee: tee, showGender: showGender, showDifficulty: showDifficulty, segment: segment)
                } else {
                    Text(placeholder)
                        .fontStyle(.poppins, size: 15, weight: .regular)
                        .foregroundStyle(Color.hackersGray)
                }

                Spacer()
                
                Icon(name: "f078", size: 12, weight: .solid)
                    .foregroundStyle(Color.hackersGray3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .border(Color.hackersGray5, width: 1.5, cornerRadius: 10)
        }
    }
}

#Preview {
    TeeDropdown()
}
