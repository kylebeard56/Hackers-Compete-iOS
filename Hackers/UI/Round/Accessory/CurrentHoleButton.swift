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
    
    @State private var showHoleList: Bool = false
    
    var body: some View {
        button
            .environmentObject(roundSession)
            .sheet(isPresented: $showHoleList) {
                HoleSelectionView()
                    .presentationDetents([.height(560), .large])
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
                    size: 20,
                    color: .systemHackersGreen
                )
                
                VStack(spacing: 0) {
                    Text("Currently on")
                        .font(.dmSans(size: 11, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Hole \(roundSession.currentHole)")
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                        .alignLeading()
                }
                
                Text("Change")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemHackersGreen)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(Color.systemHackersGreen.opacity(colorScheme.translucent))
            .cornerRadius(12)
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
