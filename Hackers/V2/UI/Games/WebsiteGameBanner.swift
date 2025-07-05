//
//  WebsiteGameBanner.swift
//  Hackers
//
//  Created by Kyle Beard on 10/18/24.
//

import SwiftUI

struct WebsiteGameBanner: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            UIApplication.shared.open(URL(string: "https://hackersgolf.app/games")!)
            Haptics.fire(.light)
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersPurple.opacity(colorScheme.translucent))
                        .frame(width: 72, height: 72)
                    Icon(name: "f672", size: 32, maxSize: 32, weight: .regular)
                        .foregroundStyle(Color.systemHackersPurple)
                }
                
                VStack(spacing: 4) {
                    Text("Discover more games")
                        .font(.dmSans, size: 17, weight: .bold)
                        .foregroundStyle(Color.systemBlack)
                    
                    Text("Check out our full list of upcoming and unique game concepts from Hackers Golf.")
                        .font(.dmSans, size: 15, weight: .regular)
                        .foregroundStyle(Color.systemGray)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .alignCenter()
            }
            .padding(20)
            .background(colorScheme.superlightGray)
            .cornerRadius(12)
            //.border(colorScheme.superlightGray, width: 2, cornerRadius: 12)
        }
    }
}

struct WebsiteGameBanner_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.systemViewBackground
            WebsiteGameBanner()
                .padding(20)
        }
        .holisticPreview()
    }
}
