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
                        .fill(Color.systemCard)
                        .cornerRadius(8)
                        .clipped()
                        .padding(4)
                        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0), radius: 12, x: 0, y: 4)
                        .opacity(isSelected ? 1 : 0.01)
                        .onTapGesture {
                            Haptics.fire(.light)
                            withAnimation(.linear(duration: 0.125)) {
                                appSession.activePack = i
                            }
                        }
                        .overlay(
                            Text(labels[i])
                                .font(.system(size: 17, weight: isSelected ? .medium : .medium))
                                .foregroundColor(isSelected ? Color.systemGrayDark : Color.systemGray4)
                        )
                }
            }
        }
        .environmentObject(appSession)
        .frame(height: 48)
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
