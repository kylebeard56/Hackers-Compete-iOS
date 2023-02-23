//
//  HoleScoringView.swift
//  Hackers
//
//  Created by Kyle Beard on 2/23/23.
//

import SwiftUI

struct HoleScoringView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var players: [Player]
    var hole: Int
    
    @State private var currentHole: Int = 1
    
    var body: some View {
        VStack(spacing: 4) {
            header
                .padding(16)
                .padding(.top, 8)

            Spacer(minLength: 0)
            
            TabView(selection: $currentHole) {
                ForEach(1..<19, id: \.self) { i in
                    content(i)
                        .padding(.top, kPadding)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .environmentObject(appSession)
        .background(Color.systemCard)
        .onAppear() {
            currentHole = hole
        }
    }
    
    // MARK: - Content
    
    private var header: some View {
        ZStack {
            BackButton(icon: .xmark, onTap: {
                dismiss()
                Haptics.fire(.light)
            })
            .alignTrailing()
            
            Text("Score Entry")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemBlack)
        }
    }
    
    private func content(_ h: Int) -> some View {
        VStack(spacing: 16) {
            Text("Hole \(h)")
                .font(.dmSans(size: 28, weight: .bold))
                .foregroundColor(Color.systemBlack)
                .alignLeading()
                            
            Divider()
            ForEach($players, id: \.self) { player in
                ScoringRow(player: player, currentHole: h)
                Divider()
            }
        }
        .padding(.horizontal, 16)
    }
}

struct HoleScoringView_Previews: PreviewProvider {
    static var players: [Player] = [
        Player(name: "Kyle", color: .blue, difficulty: .easy, redrawCount: 3, score: [:]),
        Player(name: "Santiago", color: .green, difficulty: .easy, redrawCount: 3, score: [:]),
        Player(name: "Andrew", color: .purple, difficulty: .easy, redrawCount: 3, score: [:]),
        Player(name: "Sarah", color: .red, difficulty: .easy, redrawCount: 3, score: [:])
    ]
    
    static var view: some View {
        VStack {
            RoundView()
                .sheet(isPresented: .true) {
                    HoleScoringView(players: .constant(players), hole: 1)
                        .presentationDetents([.height(230)])
                        .presentationDragIndicator(.visible)
                }
                .environmentObject(AppSession())
        }
    }
    static var previews: some View {
        Group {
            view.lightModePreview()
            view.darkModePreview()
            view.smallDevicePreview()
        }
    }
}
