//
//  WagerSliderView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/13/23.
//

import SwiftUI

struct WagerSliderView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    var hole: Int
    
    var bankerID: String = ""
    var playerID: String = ""
    
    @State private var banker: Player = Player()
    @State private var player: Player = Player()
    
    @State private var value: CGFloat = 10
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                BackButton(icon: .xmark, style: .solid, onTap: { dismiss() })
                    .opacity(0.0)
                
                Spacer(minLength: 0)
                
                Group {
                    Text("Wagers with ")
                        .foregroundColor(Color.systemBlack)
                    + Text(banker.name)
                        .foregroundColor(banker.color.value)
                }
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                BackButton(icon: .xmark, style: .solid, onTap: { dismiss() })
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            ForEach(roundSession.players.filter({ $0.id != bankerID }), id: \.self) { p in
                SliderTile(viewModel: viewModel, hole: hole, player: p)
            }
            .padding(.horizontal, 20)
            .environmentObject(roundSession)
            
            Spacer(minLength: 0)
        }
        .background(Color.systemViewBackground)
        .onAppear() {
            if let b = roundSession.players.first(where: { $0.id == bankerID }) { banker = b }
        }
    }
}

struct WagerSliderView_Previews: PreviewProvider {
    static var roundSession: RoundSession {
        let rs = RoundSession()
        rs.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
        return rs
    }
    
    static var previews: some View {
        VStack { }
            .sheet(isPresented: .true) {
                WagerSliderView(viewModel: HoleViewModel(), hole: 1, bankerID: kPlayerPablo.id)
                    .presentationDetents([.height(roundSession.players.count == 4 ? 480 : 350)])
                    .presentationDragIndicator(.visible)
                    .environmentObject(roundSession)
            }
            .holisticPreview()
    }
}
