//
//  CurrentSideGameButtn.swift
//  Hackers
//
//  Created by Kyle Beard on 7/8/23.
//

import SwiftUI

struct CurrentSideGameButton: View, OnSelectable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: HoleViewModel

    var onTap: OnTap?
    var onTapAsync: OnTapAync?
    var onItem: OnItem?
    var onItemAsync: OnItemAsync?
    
    var body: some View {
        Button(action: {
            triggerOnTap()
            Task { await triggerOnTapAsync() }
            Haptics.fire(.light)
        }) {
            HStack(spacing: 20) {
                AwesomeImage(
                    rawIcon: viewModel.sideGame.icon.unicode,
                    style: .regular,
                    size: 20,
                    color: .systemHackersPurple
                )
                
                VStack(spacing: 0) {
                    Group {
                        if viewModel.sideGame.computedFromScoring {
                            Text("Scores entered here are used for")
                        } else {
                            Text("Currently playing")
                        }
                    }
                    .font(.dmSans, size: 11, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignLeading()
                    
                    Text(viewModel.sideGame.name)
                        .font(.dmSans, size: 20, weight: .bold)
                        .foregroundColor(Color.systemHackersPurple)
                        .alignLeading()
                }
                
//                AwesomeImage(rawIcon: "f175".unicode, style: .solid, size: 15, color: .systemHackersPurple)
                
//                Text("Change")
//                    .font(.dmSans, size: 15, weight: .medium))
//                    .foregroundColor(Color.systemHackersPurple)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color.systemHackersPurple.opacity(colorScheme.translucent))
            .cornerRadius(12)
        }
    }
}

struct CurrentSideGameButton_Previews: PreviewProvider {
    static var previews: some View {
        CurrentSideGameButton(viewModel: HoleViewModel())
    }
}
