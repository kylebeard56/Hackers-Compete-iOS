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
    
    @State private var holeNumber: Int = 1
    
    @State private var scrollOffset: CGFloat = 0
    @State private var showMenu: Bool = false
    @State private var showHoleDetails: Bool = false
    @State private var showHoleList: Bool = false
    
    init() {
        // Set page control
        let pageControl = UIPageControl.appearance()
        pageControl.pageIndicatorTintColor = UIColor.systemGray5
        pageControl.currentPageIndicatorTintColor = UIColor.systemGray4
    }
    
    private var kTopSafeArea: CGFloat {
        (UIApplication.shared.currentKeyWindow?.safeAreaInsets.top ?? 56)
    }
    
    private var scrollHeight: CGFloat {
        UIScreen.main.bounds.height
        - kTopSafeArea
        - (UIApplication.shared.currentKeyWindow?.safeAreaInsets.bottom ?? 56)
        - 60
    }
    
    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                ZStack {
                    content
                        .frame(height: scrollHeight)
                    
                    //ScrollGeometry(name: "hole")
                }
                .padding(.top, 60)
            }
            //.coordinateSpace(name: "hole")
            //.onPreferenceChange(ScrollPreferenceKey.self, perform: { value in scrollOffset = value })
            
            navigationHeader
                .alignTop()
            
            if appSession.revealCards {
                CardRevealView(viewModel: gameplayViewModel)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            }
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onReceive(appSession.$rules, perform: { rules in
            //gameplayViewModel.allRules = rules.filter({ $0.packID == PackName.gameplay.rawValue })
            gameplayViewModel.reload(for: rules.filter({ $0.packID == PackName.gameplay.rawValue }))
        })
        .sheet(isPresented: $showMenu) {
            MenuView(onEnd: {
                showMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                    print("dismiss")
                    dismiss()
                })
            })
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
        .sheet(isPresented: $showHoleList) {
            HoleListView(viewModel: gameplayViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear() {
            appSession.activePack = 0
            gameplayViewModel.players = appSession.players.filter({ $0.isPlaying })
        }
        .onChange(of: gameplayViewModel.currentHole, perform: { h in self.holeNumber = h })
    }
    
    private var navigationHeader: some View {
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
                    holeNumber -= 1
                    gameplayViewModel.currentHole = holeNumber
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
                    showHoleList = true
                    Haptics.fire(.light)
                    
                }) {
                    Text("Hole \(holeNumber)")
                        .padding(.horizontal, 8)
                }

                Rectangle()
                    .fill(colorScheme == .light ? Color.systemGray4 : Color.systemGray3)
                    .frame(width: 1, height: 20, alignment: .center)
                
                Button(action: {
                    holeNumber += 1
                    gameplayViewModel.currentHole = holeNumber
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
            .opacity(0) // TODO: Hiding this until MVP 2.0
        }
        .edgesIgnoringSafeArea(.top)
        .padding(.horizontal, kPadding)
        .frame(height: kTopSafeArea)
        .background(
            Blur(style: colorScheme == .light ? .light : .dark)
                .edgesIgnoringSafeArea(.top)
        )
//            .background(
//                GeometryReader { g in Color.clear.onAppear { print("h: \(g.size.height)") } }
//            )
    }
    
    private var content: some View {
        VStack(spacing: 0) {
//            TabView(selection: $appSession.activePack) {
//                PackCard(pack: appSession.gameplayPack)
//                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
//                    .padding(.bottom, 48)
//                    .tag(0)
//                PackCard(pack: appSession.drinkingPack)
//                    .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 4)
//                    .padding(.bottom, 48)
//                    .tag(1)
//            }
//            .tabViewStyle(.page(indexDisplayMode: .always))
//            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
//            .frame(height: 250)
            
//            Picker("", selection: $appSession.activePack) {
//                Text("Gameplay").tag(0)
//                Text("Drinking").tag(1)
//            }
//            .pickerStyle(.segmented)
            PackSegmentControl()
                .padding(.horizontal, kPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            
            Group {
                if appSession.activePack == 0 {
                    GameplayView(viewModel: gameplayViewModel)
                        .padding(.vertical, kPadding)
                } else {
                    DrinkingView()
                }
            }
        }
    }
    
    // MARK: - Button Actions
    
    private func draw() {
        Task {
            await gameplayViewModel.draw()
        }
    }
    
    private func holeDetailsTapped() {
        print(#function)
    }
}

struct HoleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HoleView()
                .environmentObject(AppSession())
                .previewDevice("iPhone 14 Pro")
                .preferredColorScheme(.light)
                .previewDisplayName("Light")

            HoleView()
                .environmentObject(AppSession())
                .previewDevice("iPhone 14 Pro")
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
            
            HoleView()
                .environmentObject(AppSession())
                .previewDevice("iPhone SE (3rd generation)")
                .preferredColorScheme(.light)
                .previewDisplayName("Light")
            
            HoleView()
                .environmentObject(AppSession())
                .previewDevice("iPhone SE (3rd generation)")
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }
}
