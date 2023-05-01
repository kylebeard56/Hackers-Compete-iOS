//
//  TraditionalFrontView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/30/23.
//

import SwiftUI

struct TraditionalFrontView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject var viewModel: RoundViewModel
    
    var hole: Int
    
    var body: some View {
        VStack(spacing: 0) {
            playView
        }
        .environmentObject(appSession)
    }
    
    // MARK: - Views
    
    private var playView: some View {
        VStack(spacing: 8) {
            GameCardHeader(game: .traditional)
            
            Spacer(minLength: 0)
            
            VStack(spacing: UIScreen.isSmall ? 10 : 16) {
                HStack {
                    Text("Players")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    Text("1+")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
                HStack(spacing: 6) {
                    Text("Complexity")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    
                    Circle()
                        .fill(Color.systemHackersGreen)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3)
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(colorScheme.isLight ? Color.systemGray5 : Color.systemGray3)
                        .frame(width: 6, height: 6)
                }
                HStack {
                    Text("True scoring")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    Text("Yes")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
                HStack {
                    Text("Pace of play")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    Text("Normal")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemHackersGreen)
                }
            }
            .padding(16)
            .border(Color.systemGray6, width: 2, cornerRadius: 8)
            
            Spacer(minLength: 0)
            
            Button(action: {
                // TODO:
                Haptics.fire(.light)
            }) {
                Text("Setup rules")
                    .font(.dmSans(size: 15, weight: .bold))
                    .foregroundColor(Color.systemWhite)
                    .alignCenter()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.systemBlack)
                    .cornerRadius(8)
            }
        }
    }
}

struct TraditionalFrontView_Previews: PreviewProvider {
    static var previews: some View {
        TraditionalFrontView(viewModel: RoundViewModel(), hole: 1)
    }
}
