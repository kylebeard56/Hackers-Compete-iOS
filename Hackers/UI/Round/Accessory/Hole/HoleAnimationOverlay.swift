//
//  HoleAnimationOverlay.swift
//  Hackers
//
//  Created by Kyle Beard on 6/19/24.
//

import SwiftUI

// TODO: Add subtitle that rotate thru like Carrot does.

struct HoleAnimationOverlay: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var roundSession: RoundSession
    
    @Binding var isShown: Bool
    @Binding var hole: Int
    
    @State private var animateBackground: Bool = false
    @State private var animateLogo: Bool = false
    @State private var animateText: Bool = false
    
    var holesRemaining: Int {
        roundSession.numberOfHoles - roundSession.netHoleNumber
    }
    
    var isFinalHole: Bool {
        roundSession.holeRange.last == roundSession.currentHole
    }
    
    var body: some View {
        ZStack {
            Blur(style: colorScheme.blurStyle)
                .opacity(animateBackground ? 1 : 0)
            
            VStack {
                Spacer(minLength: 0)
                
                Text("Hole \(hole)")
                    .font(.dmSans, size: 60, weight: .bold)
                    .foregroundStyle(Color.systemBlack)
                    .opacity(animateText ? 1 : 0)
                
                Text(isFinalHole ? "Last hole" : "\(holesRemaining) left to play")
                    .font(.dmSans, size: 17, weight: .medium)
                    .foregroundStyle(Color.systemGray)
                    .opacity(animateText ? 1 : 0)
                
                Spacer(minLength: 0)
                
                Image(uiImage: Asset.Images.logoAlt.image)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width)
                    .offset(y: animateLogo ? 0 : 400)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear() {
            Haptics.fire(.light)
            animateBackground = false
            animateLogo = false
            animateText = false
            
            intro()
            outro()
        }
        .onTapGesture {
            Haptics.fire(.light)
            outro(force: true)
        }
    }
    
    private func intro() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: {
            withAnimation(.easeIn(duration: 0.3)) {
                animateBackground = true
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            withAnimation(.easeInOut(duration: 0.3)) {
                animateLogo = true
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
            withAnimation(.easeIn(duration: 0.2)) {
                animateText = true
            }
        })
    }
    
    private func outro(force: Bool = false) {
        let outro = force ? 0.0 : 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + outro, execute: {
            withAnimation(.easeIn(duration: 0.2)) {
                animateText = false
                animateLogo = false
            }
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + outro + 0.2, execute: {
            withAnimation(.easeIn(duration: 0.2)) {
                animateBackground = false
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + outro + 0.4, execute: {
            isShown = false
        })
    }
}

struct HoleAnimationOverlay_Previews: PreviewProvider {
    static var app: AppSession {
        let a = AppSession()
        a.session = Session(
            id: "",
            partyCode: "",
            players: [
                PlayerSession(player: kPlayerKyle),
                PlayerSession(player: kPlayerSarah),
                PlayerSession(player: kPlayerMurphy),
                PlayerSession(player: kPlayerPablo)
            ],
            unlockedPro: false,
            numberOfHoles: 18,
            staringHole: 1,
            sideGames: [SideGameSession()],
            createdAt: Time(),
            lastUpdatedAt: Time()
        )
        a.startingHole = 1
        a.numberOfHoles = 18
        return a
    }
    static var purchase = PurchaseStore()
    static var round: RoundSession {
        let r = RoundSession()
        r.numberOfHoles = 18
        r.netHoleNumber = 4
        return r
    }
    static var hole: Binding<Int> = .constant(1)
    
    static var previews: some View {
        ZStack {
            RoundView()
            HoleAnimationOverlay(isShown: .true, hole: hole)
        }
        .environmentObject(app)
        .environmentObject(purchase)
        .environmentObject(round)
        .holisticPreview()
    }
}
