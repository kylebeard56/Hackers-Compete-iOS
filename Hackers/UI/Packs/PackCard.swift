//
//  PackCard.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct PackCard: View {
    @EnvironmentObject var appSession: AppSession
    
    var pack: Pack
    
    var body: some View {
        VStack(spacing: kPadding) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 70, height: 70, alignment: .center)
                AwesomeImage(icon: pack.awesome, style: .regular, size: 30, color: Color.black)
            }
            
            Text(pack.name)
                .font(.dmSans(size: 28, weight: .bold))
                .foregroundColor(Color.white)
            
            Text(pack.description)
                .font(.dmSans(size: 15, weight: .regular))
                .foregroundColor(Color.black)
                .multilineTextAlignment(.center)
                .padding(.top, -12)
        }
        .environmentObject(appSession)
        .padding()
        .frame(width: UIScreen.main.bounds.width - kPadding * 2, height: 200)
        .background(
            ZStack {
                Color.white
                pack.style.linearGradient
            }
        )
        .cornerRadius(8)
    }
}

struct PackCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PackCard(pack: Pack())
                .padding(kPadding)
        }
        
    }
}
