//
//  CurrentHoleButton.swift
//  Hackers
//
//  Created by Kyle Beard on 7/7/23.
//

import SwiftUI

struct CurrentHoleButton: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession
    
    var isFinalHole: Bool = false
    
    @State private var showHoleList: Bool = false
    
    var body: some View {
        button
            .environmentObject(roundSession)
            .sheet(isPresented: $showHoleList) {
                HoleSelectionView()
                    .presentationDragIndicator(.visible)
            }
    }
    
    private var button: some View {
        Button(action: {
            showHoleList = true
            Haptics.fire(.light)
        }) {
            HStack(spacing: 20) {
                AwesomeImage(
                    rawIcon: "f450".unicode,
                    style: .regular,
                    size: 22,
                    color: Color.systemHackersGreen
                )
                
                VStack(spacing: 0) {
                    Text("Currently on")
                        .font(.dmSans, size: 11, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Hole \(roundSession.currentHole)")
                        .font(.dmSans, size: 18, weight: .bold)
                        .foregroundColor(Color.systemHackersGreen)
                        .alignLeading()
                }
                
                HStack(spacing: 8) {
                    Text(isFinalHole ? "Finish round" : "Next hole")
                        .font(.dmSans, size: 15, weight: .bold)
                        .foregroundColor(Color.systemHackersGreen)
                    
                    AwesomeImage(
                        rawIcon: (isFinalHole ? "f00c" : "f178").unicode,
                        style: .solid,
                        size: 15,
                        color: Color.systemHackersGreen
                    )
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                ZStack {
                    Color.systemBackground
                    Color.systemHackersGreen.opacity(colorScheme.translucent)
                    Blur(style: colorScheme.blurStyle).opacity(0.69)
                }
            )
            .border(Color.systemHackersGreen, width: 4, cornerRadius: 12)
            .cornerRadius(12)
            .shadow(
                color: Color.systemBlack.opacity(colorScheme.isLight ? 0.08 : 0.04),
                radius: 8,
                x: 0,
                y: -4
            )
        }
    }
}

struct CurrentHoleButton_Previews: PreviewProvider {
    static var previews: some View {
        CurrentHoleButton()
            .environmentObject(AppSession())
            .environmentObject(RoundSession())
            .padding(.horizontal, 20)
            .holisticPreview()
    }
}
