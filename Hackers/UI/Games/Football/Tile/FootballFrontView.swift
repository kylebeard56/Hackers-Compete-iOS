//
//  FootballFrontView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/29/23.
//

import SwiftUI

struct FootballFrontView: View {
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
    
    private var header: some View {
        VStack(spacing: 8) {
            if UIScreen.isSmall {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    
                    ZStack {
                        Circle()
                            .fill(Color.systemHackersGreen.opacity(0.125))
                            .frame(width: 34, height: 34)
                        AwesomeImage(rawIcon: "f44e".unicode, style: .light, size: 17, color: .systemHackersGreen)
                    }
                    
                    Text("Football")
                        .font(.fugazOne(size: 24))
                        .foregroundColor(Color.systemHackersGreen)
                        .minimumScaleFactor(0.75)
                    
                    Spacer(minLength: 0)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.systemHackersGreen.opacity(0.125))
                        .frame(width: 56, height: 56)
                    AwesomeImage(rawIcon: "f44e".unicode, style: .light, size: 28, color: .systemHackersGreen)
                }
                
                Text("Football")
                    .font(.fugazOne(size: 28))
                    .foregroundColor(Color.systemHackersGreen)
                    .alignCenter()
            }
            
            Text("Alternative point scoring based on shot outcomes for each player.")
                .font(.dmSans(size: 13, weight: .regular))
                .foregroundColor(Color.systemGray)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var playView: some View {
        VStack(spacing: 8) {
            header
            
            Spacer(minLength: 0)
            
            VStack(spacing: UIScreen.isSmall ? 10 : 16) {
                HStack {
                    Text("Players")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    Spacer(minLength: 0)
                    Text("2+")
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
                        .fill(Color.systemHackersGreen)
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
            
            Text("Coming soon")
                .font(.dmSans(size: 20, weight: .bold))
                .foregroundColor(Color.systemYellow)
                .alignCenter()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.systemYellow.opacity(0.125))
                .border(Color.systemYellow, width: 4, cornerRadius: 8)
                .cornerRadius(8)
        }
    }
}

struct FootballFrontView_Previews: PreviewProvider {
    static var previews: some View {
        FootballFrontView(viewModel: RoundViewModel(), hole: 1)
    }
}
