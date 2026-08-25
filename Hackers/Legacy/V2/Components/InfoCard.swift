//
//  InfoCard.swift
//  Hackers
//
//  Created by Kyle Beard on 7/23/23.
//

import SwiftUI

struct InfoCard: View, OnSelectable {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var title: String
    var subtitle: String
    var buttonText: String = ""
    var color: Color = .systemBlack
    
    var onTap: OnTap?
    var onTapAsync: OnTapAync?
    var onItem: OnItem?
    var onItemAsync: OnItemAsync?
    
    var body: some View {
        VStack(spacing: 10) {
            Text(LocalizedStringKey(title))
                .font(.dmSans, size: 17, weight: .bold)
                .foregroundColor(Color.systemBlack)
                .alignLeading()
            
            Text(LocalizedStringKey(subtitle))
                .font(.dmSans, size: 15, weight: .regular)
                .foregroundColor(Color.systemGray)
                .multilineTextAlignment(.leading)
                .alignLeading()
            
            Spacer(minLength: 20)
            
            if !buttonText.isEmpty {
                Button(action: {
                    triggerOnTap()
                    Task { await triggerOnTapAsync() }
                }) {
                    Text(buttonText)
                        .font(.dmSans, size: 17, weight: .bold)
                        .foregroundColor(color)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .alignCenter()
                        .background(color.opacity(colorScheme.translucent))
                        .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(Color.systemCard)
        .alignTop()
    }
}

struct InfoCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Color.systemViewBackground
        }.sheet(isPresented: .true) {
            InfoCard(
                title: "This is a test title with *formatting*",
                subtitle: "This is a test body which is going to be a tad longer and maybe _descriptive_ or **bold**.",
                buttonText: "Call to action",
                color: Color.systemHackersGreen
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .holisticPreview()
    }
}
