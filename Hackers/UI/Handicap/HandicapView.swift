//
//  HandicapView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/30/23.
//

import SwiftUI

struct HandicapView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    @State private var players: [Player] = []
    @State private var showOrder: Bool = false
    
    @State private var opacity: CGFloat = 1.0
    @State private var offset: CGFloat = 0.0
    
    private var playerWidth: CGFloat {
        let w = players.compactMap({
            $0.name.width(usingFont: .dmSans(size: 15, weight: .bold))
        }).max() ?? 100
        return min(w + 20, 100)
    }
    private let hcpWidth: CGFloat = 60
    
    @State private var holeOrder: [Int] = []
    @State private var holeOrderModified: Bool = false
    
    var body: some View {
        content
            .environmentObject(roundSession)
            .padding(.bottom, 10)
            .background(Color.systemViewBackground)
            .sheet(isPresented: $showOrder) {
                HandicapOrderView()
                    .environmentObject(roundSession)
                    .presentationDragIndicator(.visible)
            }
            .onAppear() {
                refreshOrder(for: roundSession.session)
            }
            .onReceive(roundSession.$session, perform: { session in
                refreshOrder(for: session)
            })
    }
    private func refreshOrder(for session: Session?) {
        if let order = session?.handicapHoleOrder, !order.isEmpty {
            holeOrder = order
            holeOrderModified = true
        } else {
            holeOrder = roundSession.holeRange
            holeOrderModified = false
        }
    }
    
    var content: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Handicaps")
                    .font(.dmSans, size: 28, weight: .bold)
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 20)
            
            Text("Tap squares to increment the number of strokes given per hole (max 3).")
                .foregroundColor(Color.systemBlack)
                .font(.dmSans, size: 17, weight: .regular)
                .alignLeading()
                .padding(.horizontal, 20)
            
            grid
                .padding(.leading, 20)

            SmallButton(
                title: "Re-order holes by difficulty",
                foregroundColor: Color.systemWhite,
                backgroundColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false
            )
            .onTap {
                showOrder = true
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            SmallButton(title: "Clear handicaps", isDisabled: .false, isLoading: .false)
                .onTap {
                    clearHandicaps()
                }
                .padding(.horizontal, 20)
            
            BigButton(title: "Apply handicaps", isDisabled: .false, isLoading: .false)
                .onTap {
                    applyHandicaps()
                    dismiss()
                }
                .padding(.horizontal, 20)
        }
        .onAppear() { self.players = roundSession.players }
        .onReceive(roundSession.$players, perform: { p in self.players = p })
    }
    
    // MARK: - Grid
    
    @ViewBuilder private var grid: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 20) {
                        ForEach(Array(zip(holeOrder.indices, holeOrder)), id: \.0) { i, h in
                            VStack(alignment: .center, spacing: 20) {
                                VStack(spacing: 12) {
                                    Text("\(h)")
                                        .font(.dmSans, size: 15, weight: .bold)
                                        .foregroundColor(Color.systemBlack)
                                    
                                    if holeOrderModified {
                                        Text("\(i+1)")
                                            .font(.dmSans, size: 11, weight: .bold)
                                            .foregroundColor(Color.systemGray2)
                                    }
                                }

                                ForEach(0..<players.count, id: \.self) { i in
                                    button(for: i, on: h)
                                        .id(h)
                                }
                            }
                        }
                        
                        Text("")
                    }
                    .padding(.leading, playerWidth + hcpWidth)
                    .background(ScrollGeometry(name: "handicaps", orientation: .horizontal))
                }
            }
            .coordinateSpace(name: "handicaps")
            .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in setScroll(for: v) })
            .alignTrailing()
            
            ZStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 20) {

                    VStack(spacing: 12) {
                        Text("Hole")
                            .font(.dmSans, size: 15, weight: .bold)
                            .foregroundColor(Color.systemBlack)
                            .frame(width: hcpWidth, alignment: .leading)
                            .lineLimit(1)
                            .offset(x: -offset)
                        
                        if holeOrderModified {
                            Text("Difficulty")
                                .font(.dmSans, size: 11, weight: .bold)
                                .foregroundColor(Color.systemGray2)
                                .frame(width: hcpWidth, alignment: .leading)
                                .lineLimit(1)
                                .offset(x: -offset)
                        }
                    }

                    ForEach(players, id: \.self) { player in
                        ZStack {
                            Text("\(player.name)")
                                .font(.dmSans, size: 15, weight: .bold)
                                .foregroundColor(player.color.value)
                                .frame(width: playerWidth, height: 40, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .opacity(opacity)
                                .alignLeading()
                            
                            Text("\(player.handicapIndex)")
                                .font(.dmSans, size: 15, weight: .bold)
                                .foregroundColor(player.color.value)
                                .frame(width: 40, height: 40, alignment: .center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .background(player.color.value.opacity(colorScheme.translucent))
                                .cornerRadius(6)
                                .alignTrailing()
                                .padding(.trailing, 20)
                        }
                        .frame(width: playerWidth + hcpWidth)
                    }
                }
            }
            .background(Color.systemViewBackground)
            .offset(x: offset)
            .alignLeading()
            
            LinearGradient(colors: [.systemBlack, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 8, height: shadowHeight)
                .padding(.leading, hcpWidth)
                .alignLeading()
                .opacity(opacity == 0 && colorScheme.isLight ? 0.03 : 0.00)
        }
    }
    
    private func setScroll(for v: CGFloat) {
        if v < 0 {
            if v < -playerWidth {
                opacity = 0
                offset = -playerWidth
            } else {
                opacity = (1 - abs(v) * 1 / playerWidth)
                offset = min(v, playerWidth)
            }
        } else {
            opacity = 1
            offset = 0
        }
    }
    
    private var shadowHeight: CGFloat {
        return 20.0 + (60.0 * CGFloat(roundSession.players.count))
    }
    
    @ViewBuilder private func button(for i: Int, on h: Int) -> some View {
        let current = players[i].handicap[h] ?? 0
        
        var foregroundColor: Color {
            switch current {
            case 0:     return .clear
            case 1:     return .systemBlack
            default:    return .systemWhite
            }
        }
        
        var backgroundColor: Color {
            switch current {
            case 0:     return .clear
            case 1:     return colorScheme.lightGray
            case 2:     return .systemGray
            case 3:     return .systemBlack
            default:    return .clear
            }
        }
        
        Button {
            players[i].handicap.updateValue(current + 1, forKey: h)
            if players[i].handicap[h] == 4 {
                players[i].handicap.updateValue(0, forKey: h)
            }
            Haptics.fire(.light)
        } label: {
            Text("\(current)")
                .font(.dmSans, size: 15, weight: .bold)
                .foregroundColor(foregroundColor)
                .frame(width: 40, height: 40)
                .background(backgroundColor)
                .border(current == 0 ? colorScheme.lightGray : Color.clear, width: 3, cornerRadius: 6)
                .cornerRadius(6)
        }
    }
    
    // MARK: - Functions
    
    private func clearHandicaps() {
        roundSession.players = roundSession.players.compactMap {
            var p = $0
            p.handicap = [:]
            return p
        }
    }
    
    private func applyHandicaps() {
        roundSession.players = self.players
    }
}

struct HandicapView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var previews: some View {
        HandicapView()
            .environmentObject(roundSession)
            .onAppear() {
                //roundSession.holeRange = Array(1...18)
                //roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
                roundSession.loadSession(
                    Session(
                        id: "id",
                        players: [
                            PlayerSession(player: kPlayerKyle),
                            PlayerSession(player: kPlayerSarah),
                            PlayerSession(player: kPlayerMurphy),
                            PlayerSession(player: kPlayerPablo)
                        ],
                        numberOfHoles: 9,
                        staringHole: 1
                    )
                )
            }
            .holisticPreview()
    }
}
