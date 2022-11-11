//
//  HoleView.swift
//  Hackers
//
//  Created by Kyle Beard on 10/25/22.
//

import SwiftUI

struct HoleView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @StateObject var gameplayViewModel = GameplayViewModel()
    
    var holeNumber: Int
    
    @State private var scrollOffset: CGFloat = 0
    @State private var showMenu: Bool = false
    @State private var showHoleDetails: Bool = false
    @State private var navigateToNextHole: Bool = false
    @State private var endRound: Bool = false
    
    init(holeNumber: Int = 1) {
        self.holeNumber = holeNumber
        
        // Set page control
        let pageControl = UIPageControl.appearance()
        pageControl.pageIndicatorTintColor = UIColor.systemGray5
        pageControl.currentPageIndicatorTintColor = UIColor.systemGray4
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                ZStack {
                    content
                    ScrollGeometry(name: "hole")
                }
                .padding(.top, 60)
            }
            .coordinateSpace(name: "hole")
            .onPreferenceChange(ScrollPreferenceKey.self, perform: { value in scrollOffset = value })
            
            HStack {
                Button(action: {
                    showMenu = true
                    Haptics.fire(.light)
                }) {
                    AwesomeImage(icon: .menuBars, style: .regular, size: 24, color: Color.systemBlack)
                }
                
                Spacer()
                
                HStack(spacing: kPadding) {
                    Button(action: {
                        print("todo: previous")
                        Haptics.fire(.light)
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundColor(holeNumber < 2 ? Color.systemGray2 : Color.systemBlack)
                    .disabled(holeNumber < 2)
                    
                    Rectangle()
                        .fill(colorScheme == .light ? Color.systemGray4 : Color.systemGray3)
                        .frame(width: 1, height: 20, alignment: .center)
                    
                    Button(action: {
                        print("todo: hole selector shortcut")
                        Haptics.fire(.light)
                        
                    }) {
                        Text("Hole \(holeNumber)")
                            .padding(.horizontal, 8)
                    }

                    Rectangle()
                        .fill(colorScheme == .light ? Color.systemGray4 : Color.systemGray3)
                        .frame(width: 1, height: 20, alignment: .center)
                    
                    Button(action: {
                        print("todo: next")
                        Haptics.fire(.light)
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(holeNumber > 18 ? Color.systemGray2 : Color.systemBlack)
                    .disabled(holeNumber > 18)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.systemBlack)
                .padding(.horizontal, kPadding)
                .padding(.vertical, 6)
                .background(colorScheme == .light ? Color.systemGray6 : Color.systemGray5)
                .cornerRadius(8)
                
                Spacer()
                
                Button(action: {
                    showHoleDetails = true
                    Haptics.fire(.light)
                }) {
                    AwesomeImage(icon: .golfFlagHole, style: .regular, size: 24, color: Color.systemBlack)
                }
            }
            .edgesIgnoringSafeArea(.top)
            .padding(.horizontal, kPadding)
            .frame(height: UIApplication.shared.currentKeyWindow?.safeAreaInsets.top ?? 56)
            .background(
                Blur(style: colorScheme == .light ? .light : .dark)
                    .edgesIgnoringSafeArea(.top)
            )
            .alignTop()
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $appSession.shouldEndRound, destination: { LandingView() })
        .sheet(isPresented: $showMenu) {
            MenuView()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHoleDetails) {
            HoleDetailView(
                details: appSession.holes[holeNumber - 1].details,
                hole: holeNumber,
                onSave: { d in appSession.holes[holeNumber - 1].details = d }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear() {
            appSession.activePack = 0
        }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            TabView(selection: $appSession.activePack) {
                PackCard(pack: kGameplayPack)
                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 48)
                    .tag(0)
                PackCard(pack: kDrinkingPack)
                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 48)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .frame(height: 250)
            
            Group {
                if appSession.activePack == 0 {
                    GameplayView(viewModel: gameplayViewModel)
                } else {
                    drinkingRules
                }
            }
        }
    }
    
    private var drinkingRules: some View {
        VStack(spacing: kPadding) {
            Spacer()
            Text("Drinking rules here")
                .foregroundStyle(kDrinkingPack.style.linearGradient)
                .font(.dmSans(size: 32, weight: .medium))
                .alignCenter()
            Spacer()
        }
        .frame(height: 500)
        .border(Color.systemGray5, width: 2, cornerRadius: 20)
        .padding(kPadding)
    }
    
    // MARK: - Button Actions
    
    private func holeDetailsTapped() {
        print(#function)
    }
}

struct HoleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HoleView(holeNumber: 1)
                .environmentObject(AppSession())
                .previewDevice("iPhone 14 Pro")
                .preferredColorScheme(.light)
                .previewDisplayName("Light")
            
            HoleView(holeNumber: 1)
                .environmentObject(AppSession())
                .previewDevice("iPhone 14 Pro")
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }
}
