//
//  WagerSliderView.swift
//  Hackers
//
//  Created by Kyle Beard on 8/13/23.
//

import SwiftUI

struct SliderData {
    var id: String = UUID().uuidString
    var player: Player
    var value: CGFloat = 1
    var max: CGFloat = 100
}

struct WagerSliderView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel: HoleViewModel
    
    var hole: Int
    var bankerID: String = ""
    
    @State private var banker: Player = Player()
    @State private var data: [SliderData] = []
    
    private var max: Int {
        viewModel.sideGameSession.banker?.maxWager ?? 100
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Wagers")
                    .font(.dmSans, size: 28, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.top, 20)
            
//            Group {
//                Text("Wagers range from 5 to 100, but ")
//                    .foregroundColor(Color.systemBlack)
//                    //.font(.dmSans, size: 17, weight: .regular)
//                + Text("**\(banker.name)**")
//                    .foregroundColor(banker.color.value)
//                    //.font(.dmSans, size: 17, weight: .bold)
//                + Text(" can choose to lower the maximum based on comfort level.")
//                    .foregroundColor(Color.systemBlack)
//                    //.font(.dmSans, size: 17, weight: .regular)
//            }
//            .font(.dmSans, size: 17)
//            .alignLeading()
            
            ForEach($data, id: \.id.wrappedValue) { d in
                SliderTile(data: d)
            }
            
            Spacer(minLength: 0)
            
            SmallButton(
                title: "I'm feeling lucky",
                isDisabled: .false,
                isLoading: .false
            )
            .onTap {
                for i in 0..<data.count {
                    withAnimation(.linear(duration: 0.2)) {
//                        let random = Int.random(in: 1...(max / 5))
//                        data[i].value = CGFloat(random) * 5.0
                        data[i].value = CGFloat(Int.random(in: 1...max))
                    }
                }
            }
            
            BigButton(
                title: "Confirm wagers with \(banker.name)",
                buttonColor: banker.color.value,
                isDisabled: .false,
                isLoading: .false
            )
            .onTap {
                let w = data.reduce(into: [:], { $0[$1.player.id] = Int($1.value) })
                viewModel.sideGameSession.banker?.wagers[hole] = w
                dismiss()
            }
        }
        .padding(.horizontal, 20)
        .background(Color.systemViewBackground)
        .onAppear() {
            if let b = roundSession.players.first(where: { $0.id == bankerID }) { banker = b }
            data = roundSession.players.filter({ $0.id != bankerID }).compactMap({
                SliderData(
                    player: $0,
                    value: CGFloat(viewModel.sideGameSession.banker?.wagers[hole]?[$0.id] ?? 1),
                    max: CGFloat(max)
                )
            })
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .environmentObject(roundSession)
            }
            .holisticPreview()
    }
}
