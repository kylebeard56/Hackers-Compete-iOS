//
//  FlippableCardView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/27/23.
//

import SwiftUI

struct FlippableCardView<Header: View, Content: View>: View {
    @Binding var isFlipped: Bool
    @ViewBuilder var front: () -> Header
    @ViewBuilder var back: () -> Content
    
    @State private var backDegree = 0.0
    @State private var frontDegree = -90.0
    @State private var scaleFactor: CGFloat = 1.0
    
    let durationAndDelay: CGFloat = 0.375
    
    var body: some View {
        VStack {
            if isFlipped {
                back().rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                front()
            }
        }
        .padding(16)
        .background(Color.systemCard)
        .border(Color.systemGray5, width: 2, cornerRadius: 16)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .scaleEffect(scaleFactor)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            flipCard()
            Haptics.fire(.light)
        }
    }
    
    private func flipCard () {
        withAnimation(.easeInOut(duration: durationAndDelay)) {
            isFlipped.toggle()
        }
        
        withAnimation(.easeInOut(duration: durationAndDelay / 2)) {
            scaleFactor = 0.75 // Tested on preview, corners don't clip.
        }

        withAnimation(.easeInOut(duration: durationAndDelay / 2).delay(durationAndDelay / 2)) {
            scaleFactor = 1.0
        }
    }
}

struct FlippableCardView_Previews: PreviewProvider {
    static var previews: some View {
        FlippableCardView(isFlipped: .false, front: {
            ZStack {
                Color.red
                Text("Front")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
        }, back: {
            ZStack {
                Color.blue
                Text("Back")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
        })
    }
}
