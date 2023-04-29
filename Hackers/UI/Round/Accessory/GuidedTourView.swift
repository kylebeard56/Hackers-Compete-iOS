//
//  GuidedTourView.swift
//  Hackers
//
//  Created by Kyle Beard on 3/12/23.
//

import SwiftUI

struct GuidedTourView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var tab: Int = 0
    
    var body: some View {
        TabView(selection: $tab) {
            welcomeView
                .padding(16)
                .tag(0)
            holeNavigationView
                .padding(16)
                .tag(1)
            scoringView
                .padding(16)
                .tag(2)
            gameView
                .padding(16)
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.systemBackground)
        .onChange(of: tab, perform: { _ in Haptics.fire(.light) })
    }
    
    private func tab(to index: Int) {
        withAnimation(.linear(duration: 0.2)) {
            tab = index
        }
    }
    
    // MARK: - Welcome
    
    private var welcomeView: some View {
        VStack(spacing: 16) {
            stackedGraphic(for: [
                AwesomeImage(icon: .pencil, style: .regular, size: 20, color: .systemGreenDark),
                AwesomeImage(icon: .golfClub, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(icon: .golfBallTee, style: .regular, size: 36, color: .systemGreenDark),
                AwesomeImage(icon: .golfFlagHole, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(icon: .cardsBlank, style: .regular, size: 20, color: .systemGreenDark),
            ])
            
            VStack(spacing: 8) {
                Text("Welcome to Hackers")
                    .font(.dmSans(size: 22, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                PillDivider()
                    .padding(.vertical, 8)
                
                Text("Learn how to quickly navigate between holes, enter score for the party, and play games.")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemGrayDark)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, -16)
            
            Spacer(minLength: 0)
            
            Button(action: { tab(to: 1) }) {
                Text("Next")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.white)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(Color.systemGreenDark)
            .cornerRadius(12)
            
            Button(action: {
                Haptics.fire(.light)
                FirebaseEvent.guidedTourSkipped.log()
                dismiss()
            }) {
                Text("Skip")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(colorScheme == .light ? Color.systemGray6 : Color.systemGray5)
            .cornerRadius(12)
        }
    }
    
    private var holeNavigationView: some View {
        VStack(spacing: 16) {
            stackedGraphic(for: [
                AwesomeImage(icon: .golfFlagHole, style: .regular, size: 20, color: .systemGreenDark),
                AwesomeImage(icon: .arrowLeftLong, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(rawIcon: "e1a2".unicode, style: .regular, size: 36, color: .systemGreenDark),
                AwesomeImage(icon: .arrowRightLong, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(icon: .golfBallTee, style: .regular, size: 20, color: .systemGreenDark),
            ])
            
            VStack(spacing: 8) {
                Text("Navigating holes")
                    .font(.dmSans(size: 22, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                PillDivider()
                    .padding(.vertical, 8)
                
                Text("Swipe back and forth to change holes. Quickly jump between holes by tapping the hole number.")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemGrayDark)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, -16)
            
            Spacer(minLength: 0)
            
            Button(action: { tab(to: 2) }) {
                Text("Next")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.white)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(Color.systemGreenDark)
            .cornerRadius(12)
        }
    }
    
    private var scoringView: some View {
        VStack(spacing: 16) {
            stackedGraphic(for: [
                AwesomeImage(icon: .golfFlagHole, style: .regular, size: 20, color: .systemGreenDark),
                AwesomeImage(rawIcon: "f007".unicode, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(icon: .pencil, style: .regular, size: 36, color: .systemGreenDark),
                AwesomeImage(rawIcon: "e473".unicode, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(icon: .golfBallTee, style: .regular, size: 20, color: .systemGreenDark),
            ])
            
            VStack(spacing: 8) {
                Text("Keeping score")
                    .font(.dmSans(size: 22, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                PillDivider()
                    .padding(.vertical, 8)
                
                Text("Tap scorecard button to add scores for each holes. Tap on a player scorebox to see their full card. Swipe back and forth to change hole or player while viewing scores.")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemGrayDark)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, -16)
            
            Spacer(minLength: 0)
            
            Button(action: { tab(to: 3) }) {
                Text("Next")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.white)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(Color.systemGreenDark)
            .cornerRadius(12)
        }
    }
    
    private var gameView: some View {
        VStack(spacing: 16) {
            stackedGraphic(for: [
                AwesomeImage(icon: .golfFlagHole, style: .regular, size: 20, color: .systemGreenDark),
                AwesomeImage(rawIcon: "f062".unicode, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(rawIcon: "f11b".unicode, style: .regular, size: 36, color: .systemGreenDark),
                AwesomeImage(rawIcon: "f063".unicode, style: .regular, size: 28, color: .systemGreenDark),
                AwesomeImage(icon: .golfBallTee, style: .regular, size: 20, color: .systemGreenDark),
            ])
            
            VStack(spacing: 8) {
                Text("Playing games")
                    .font(.dmSans(size: 22, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                
                PillDivider()
                    .padding(.vertical, 8)
                
                Text("Swipe up and down to navigate games and see fun ways to play holes during your round. Tap cards to see instructions on the back.")
                    .font(.dmSans(size: 15, weight: .medium))
                    .foregroundColor(Color.systemGrayDark)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, -16)
            
            Spacer(minLength: 0)
            
            Button(action: {
                Haptics.fire(.light)
                FirebaseEvent.guidedTourFinished.log()
                dismiss()
            }) {
                Text("Let's play")
                    .font(.dmSans(size: 16, weight: .medium))
                    .foregroundColor(Color.white)
                    .alignCenter()
            }
            .padding()
            .frame(height: 50)
            .background(Color.systemGreenDark)
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func stackedGraphic(for icons: [AwesomeImage]) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.systemGreenDark, lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.systemGreenDark.opacity(0.125))
                    .frame(width: 40, height: 40)
                
                icons[0]
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.systemGreenDark, lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.systemGreenDark.opacity(0.125))
                    .frame(width: 56, height: 56)
                
                icons[1]
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.systemGreenDark, lineWidth: 3)
                    .frame(width: 72, height: 72)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.systemGreenDark.opacity(0.125))
                    .frame(width: 72, height: 72)
                
                icons[2]
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.systemGreenDark, lineWidth: 3)
                    .frame(width: 56, height: 56)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.systemGreenDark.opacity(0.125))
                    .frame(width: 56, height: 56)
                
                icons[3]
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.systemGreenDark, lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.systemGreenDark.opacity(0.125))
                    .frame(width: 40, height: 40)
                
                icons[4]
            }
        }
        .padding(.vertical, 24)
    }
}

struct GuidedTourView_Previews: PreviewProvider {
    static var view: some View {
        RoundView()
            .environmentObject(AppSession())
            .sheet(isPresented: .true) {
                GuidedTourView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
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
