//
//  PackToggle.swift
//  Hackers
//
//  Created by Kyle Beard on 1/28/23.
//

import SwiftUI

struct PackSegmentControl: View {
    @EnvironmentObject var appSession: AppSession
    
    @State private var labels: [String] = []
    @State private var packs: [Pack] = []

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.systemGray6)
                .cornerRadius(12)
            HStack(spacing: 0) {
                ForEach(labels.indices, id: \.self) { i in
                    let isSelected = appSession.activePack == i
                    Rectangle()
                        .fill(Color.systemWhite)
                        .cornerRadius(8)
                        .clipped()
                        .padding(4)
                        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0), radius: 12, x: 0, y: 4)
                        .opacity(isSelected ? 1 : 0.01)
                        .onTapGesture {
                            withAnimation(.linear(duration: 0.125)) {
                                appSession.activePack = i
                            }
                        }
                        .overlay(
                            HStack {
                                let p = packs[i]
                                if isSelected {
                                    AwesomeImage(
                                        icon: p.awesome,
                                        style: .regular,
                                        size: 15,
                                        color: p.style.primaryColor,
                                        secondaryColor: p.style.secondaryColor)
                                }
                                Text(labels[i])
                                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? p.style.linearGradient : Color.systemGray2.toGradient)
                            }
                        )
                }
            }
        }
        .environmentObject(appSession)
        .frame(height: 56)
        .onAppear() {
            labels = ["Gameplay", "Drinking"]
            packs = [appSession.gameplayPack, appSession.drinkingPack]
        }
    }
}

struct PackSegmentControl_Previews: PreviewProvider {
    static let appSession = AppSession()
    static var previews: some View {
        Group {
            PackSegmentControl()
                .padding(kPadding)
                .lightModePreview()
                .environmentObject(appSession)
            PackSegmentControl()
                .padding(kPadding)
                .darkModePreview()
                .environmentObject(appSession)
        }
    }
}
