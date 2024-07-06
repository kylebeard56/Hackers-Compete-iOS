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
    
    var isFinalHole: Bool {
        roundSession.holeRange.last == roundSession.currentHole
    }
    
    @State private var showHoleList: Bool = false
    
    private var nextHoleNumber: Int {
        if let i = roundSession.holeRange.firstIndex(where: { $0 == roundSession.currentHole }) {
            return roundSession.holeRange[safe: i + 1] ?? -999
        } else {
            return -999
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
//            Rectangle()
//                .fill(Color.systemHackersGreen)
//                .frame(height: 3)
            button
                .environmentObject(roundSession)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
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
//            Rectangle()
//                .fill(Color.systemHackersGreen)
//                .frame(height: 3)
        }
//        .sheet(isPresented: $showHoleList) {
//            HoleSelectionView()
//                .presentationDragIndicator(.visible)
//        }
    }
    
    private var button: some View {
        Button(action: {
            if isFinalHole {
                Task { await appSession.leaveRound() }
            } else {
                roundSession.currentHole = nextHoleNumber
            }
            Haptics.fire(.light)
        }) {
            HStack(spacing: 20) {
//                AwesomeImage(
//                    rawIcon: "e3ac".unicode,
//                    style: .regular,
//                    size: 22,
//                    color: Color.systemHackersGreen
//                )
                
                VStack(spacing: 0) {
                    Text("Completed")
                        .font(.dmSans, size: 11, weight: .bold)
                        .foregroundColor(Color.systemBlack)
                        .alignLeading()
                    
                    Text("Hole \(roundSession.currentHole)")
                        .font(.dmSans, size: 20, weight: .bold)
                        .foregroundColor(Color.systemHackersGreen)
                        .alignLeading()
                }
                
                HStack(spacing: 8) {
                    Text(isFinalHole ? "Finish round" : "Next hole")
                        .font(.dmSans, size: 17, weight: .bold)
                        .foregroundColor(Color.systemHackersGreen)
                    
                    AwesomeImage(
                        rawIcon: (isFinalHole ? "f00c" : "f178").unicode,
                        style: .solid,
                        size: 17,
                        color: Color.systemHackersGreen
                    )
                }
            }
        }
    }
}

struct CurrentHoleButton_Previews: PreviewProvider {
    static var previews: some View {
        CurrentHoleButton()
            .environmentObject(AppSession())
            .environmentObject(RoundSession())
            //.padding(.horizontal, 20)
            .holisticPreview()
    }
}
