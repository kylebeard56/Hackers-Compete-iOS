//
//  SliderTile.swift
//  Hackers
//
//  Created by Kyle Beard on 8/14/23.
//

import SwiftUI

struct SliderTile: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var data: SliderData
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(data.player.name)
                    .font(.dmSans, size: 20, weight: .bold)
                    .foregroundColor(data.player.color.value)
                
                Spacer(minLength: 0)
                
                Text("\(Int(data.value))")
                    .font(.dmSans, size: 20, weight: .bold)
                    .foregroundColor(data.player.color.value)
                    .frame(width: 48, height: 40)
                    .background(data.player.color.value.opacity(colorScheme.translucent))
                    .cornerRadius(8)
            }
            
            Slider(
                value: $data.value,
                in: 5...100,
                step: 5
            ) {
                Text("Wager")
            } minimumValueLabel: {
                Text("5").font(.dmSans, size: 13, weight: .bold)
            } maximumValueLabel: {
                Text("100").font(.dmSans, size: 13, weight: .bold)
            }
            .tint(data.player.color.value)
            .onChange(of: data.value, perform: { _ in
                Haptics.fire(.light)
            })
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.systemCard)
        .border(colorScheme.lightGray, width: 3, cornerRadius: 12)
        .cornerRadius(12)
    }
}
