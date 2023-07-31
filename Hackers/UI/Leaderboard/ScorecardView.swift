//
//  ScorecardView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/30/23.
//

import SwiftUI

struct ScorecardView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    
    var autoscroll: Bool = true
    @State private var players: [Player] = []
    
    @State private var opacity: CGFloat = 1.0
    @State private var offset: CGFloat = 0.0
    
    private var playerWidth: CGFloat {
        let w = players
            .compactMap({ $0.name.width(usingFont: .dmSans(size: 15, weight: .bold)) })
            .max() ?? 120
        return min(w, 120)
    }
    
    private var hcpWidth: CGFloat {
        let w = players
            .compactMap({ "\($0.handicapIndex)".width(usingFont: .dmSans(size: 15, weight: .bold)) })
            .max() ?? 60
        return w + 10
    }
    
    var body: some View {
        content
            .environmentObject(roundSession)
            .padding(.bottom, 10)
            .background(Color.systemViewBackground)
    }
    
    var content: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Handicaps")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 20)
            
            Text("Tap squares to increment the number of strokes given per hole (max 3).")
                .foregroundColor(Color.systemBlack)
                .font(.dmSans(size: 17, weight: .regular))
                .alignLeading()
                .padding(.horizontal, 20)
            
            grid
                .padding(.leading, 20)
            
            // TODO: Tapping show info on how to assign HCP with other context.
            InfoBanner(text: "Allocate handicaps by most to least difficult holes from scorecard (1 = hardest, 18 = easiest).")
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 20)
            
            // TODO: Normalize if desired (in future).
            
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
            HStack(spacing: 20) {
                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Hole")
                            .font(.dmSans(size: 15, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                        ForEach(players, id: \.self) { player in
                            ZStack {
                                Text("\(player.name)")
                                    .font(.dmSans(size: 15, weight: .bold))
                                    .foregroundColor(player.color.value)
                                    .frame(height: 40)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .padding(.trailing, hcpWidth)
                                    .opacity(opacity)
                                    .alignLeading()
                                
                                Text("\(player.handicapIndex)")
                                    .font(.dmSans(size: 15, weight: .bold))
                                    .foregroundColor(player.color.value)
                                    .frame(height: 40)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(width: hcpWidth)
                                    .alignTrailing()
                            }
                            .frame(width: playerWidth + hcpWidth + offset)
                        }
                    }
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(spacing: 20) {
                            ForEach(roundSession.holeRange, id: \.self) { h in
                                VStack(alignment: .center, spacing: 20) {
                                    Text("\(h)")
                                        .font(.dmSans(size: 15, weight: .bold))
                                        .foregroundColor(Color.systemBlack)
                                    
                                    ForEach(0..<players.count, id: \.self) { i in
                                        button(for: i, on: h)
                                            .id(h)
                                    }
                                }
                                .onAppear() {
                                    if !autoscroll { return }
                                    withAnimation(.linear(duration: 0.2)) {
                                        proxy.scrollTo(roundSession.currentHole, anchor: .leading)
                                    }
                                }
                            }
                            
                            Text("")
                        }
                        .background(ScrollGeometry(name: "handicaps", orientation: .horizontal))
                    }
                }
                .coordinateSpace(name: "handicaps")
                .onPreferenceChange(ScrollPreferenceKey.self, perform: { v in
                    if v < 0 {
                        if v < -playerWidth {
                            withAnimation(.linear(duration: 0.2)) {
                                opacity = 0
                                offset = -playerWidth
                            }
                        } else {
                            opacity = (1 - abs(v) * 1 / playerWidth)
                            offset = min(v, playerWidth)
                        }
                    } else {
                        opacity = 1
                        offset = 0
                    }
                })
            }
            
            LinearGradient(colors: [.systemBlack, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 8, height: shadowHeight)
                .padding(.leading, hcpWidth + 20)
                .alignLeading()
                .opacity(opacity == 0 && colorScheme.isLight ? 0.03 : 0.00)
        }
    }
    
    private var shadowHeight: CGFloat {
        return 15.0 + (60.0 * CGFloat(roundSession.players.count))
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
            case 1:     return .systemGray6
            case 2:     return .systemGray2
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
                .font(.dmSans(size: 15, weight: .bold))
                .foregroundColor(foregroundColor)
                .frame(width: 40, height: 40)
                .background(backgroundColor)
                .border(current == 0 ? Color.systemGray5 : Color.clear, width: 3, cornerRadius: 6)
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

struct ScorecardView_Previews: PreviewProvider {
    static var roundSession = RoundSession()
    static var previews: some View {
        ScorecardView()
            .environmentObject(roundSession)
            .onAppear() {
                roundSession.holeRange = Array(1...18)
                roundSession.players = [kPlayerKyle, kPlayerSarah, kPlayerMurphy, kPlayerPablo]
            }
            .holisticPreview()
    }
}
