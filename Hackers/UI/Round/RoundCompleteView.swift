//
//  RoundCompleteView.swift
//  Hackers
//
//  Created by Kyle Beard on 4/4/23.
//

import SwiftUI

struct RoundCompleteView: View, WindowPresentable {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appSession: AppSession
    @StateObject private var viewModel = RoundSummaryViewModel()
    
    var body: some View {
        ZStack {
            Blur(style: .dark)
                .opacity(0.420)
                .edgesIgnoringSafeArea(.all)
            Color.black
                .opacity(0.69)
                .edgesIgnoringSafeArea(.all)
            
            content
                .padding(.horizontal, 16)
        }
        .onAppear() {
            if let s = appSession.session {
                viewModel.load(s, appSession.rules)
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Round Complete")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
                
                Text("Someone in your party ended this round.")
                    .font(.dmSans(size: 15, weight: .regular))
                    .foregroundColor(Color.systemGrayDark)
            }
            
            PillDivider()
            
            ForEach(0..<viewModel.playerResult.count, id: \.self) { i in
                let result = viewModel.playerResult[i]
                HStack(spacing: 16) {
                    Circle()
                        .fill(result.color)
                        .frame(width: 8, height: 8)
                    Text(result.name)
                        .font(.dmSans(size: 20, weight: .medium))
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer()
                    
                    Text(result.scoreTotal.toGolfScore)
                        .font(.dmSans(size: 20, weight: .bold))
                        .foregroundColor(result.color)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.systemGray6.opacity(0.5))
                        .cornerRadius(4)
                }
            }
            
            BigButton(
                style: .solid,
                title: "Done",
                labelColor: Color.systemWhite,
                buttonColor: Color.systemBlack,
                isDisabled: .false,
                isLoading: .false,
                onTap: {
                    clearPresentedWindow()
                    Task(operation: appSession.endRound)
                }
            )
        }
        .padding(16)
        .background(Color.systemCard)
        .cornerRadius(16)
    }
}

struct RoundCompleteView_Previews: PreviewProvider {
    static var view: some View {
        ZStack {
            ForEach(0..<40, id: \.self) { _ in
                Text("Hackers is the best golf app")
            }
            RoundCompleteView()
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
