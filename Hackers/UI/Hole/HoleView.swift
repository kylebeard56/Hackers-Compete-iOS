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
    
    @StateObject var viewModel = RoundViewModel()
    
    @State private var holeNumber: Int = 1
    
    @State private var scrollOffset: CGFloat = 0
    @State private var showMenu: Bool = false
    @State private var showHoleDetails: Bool = false
    @State private var showHoleList: Bool = false
    
    @State private var showHome: Bool = false
    
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
                }
                .padding(.top, 60)
            }

            if !viewModel.sessionEnded {
                navigationHeader
                    .alignTop()
            }

            if appSession.revealCards {
                CardRevealView(viewModel: viewModel)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            }
        }
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        /// ON APPEAR
        .onAppear() {
            appSession.activePack = 0
            viewModel.players = appSession.players.filter({ $0.isPlaying })
            viewModel.reload(for: appSession.rules.filter({ $0.packID == PackName.gameplay.rawValue }))
            if let s = appSession.session {
                viewModel.loadSession(s)
            }
        }
        /// ON CHANGE OR RECEIVE
        .onChange(of: viewModel.currentHole, perform: { h in self.holeNumber = h })
        .onChange(of: viewModel.currentHole, perform: { h in self.holeNumber = h })
        .onReceive(appSession.$rules, perform: { rules in
            viewModel.reload(for: rules.filter({ $0.packID == PackName.gameplay.rawValue }))
        })
        .onReceive(HackersNotification.sessionUpdated.publisher(), perform: { data in
            if let session = data.object as? Session {
                print("session update received")
                viewModel.loadSession(session)
            } else {
                print("session update detected")
                Task(operation: viewModel.fetchSession)
            }
        })
        /// SHEETS
        .fullScreenCover(isPresented: $showHome) { LandingView() }
        .sheet(isPresented: $showMenu) {
            MenuView(onPartyCode: { code in viewModel.sessionCode = code }, onEnd: {
                showMenu = false
                appSession.endRound()
                showHome = true
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: {
//                    appSession.endRound()
//                    dismiss()
//                })
            })
            .presentationDetents([.height(350)])
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
            HoleListView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
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
                    viewModel.currentHole = holeNumber
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
                    viewModel.currentHole = holeNumber
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
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            if viewModel.sessionEnded {
                VStack(spacing: 8) {
                    Text("This round is over")
                        .font(.dmSans(size: 28, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    
                    Text("Someone in your party has ended this round.")
                        .font(.dmSans(size: 15, weight: .regular))
                        .foregroundColor(Color.systemGrayDark)
                }
                .padding(.horizontal, kPadding)
               
                Spacer(minLength: 0)
                
                BigButton(
                    style: .solid,
                    title: "To the 19th hole",
                    labelColor: Color.systemWhite,
                    buttonColor: Color.systemBlack,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: {
                        appSession.endRound(callFirebase: false)
                        showHome = true
                    }
                )
                .padding(.horizontal, kPadding)
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            } else {
                PackSegmentControl()
                    .padding(.horizontal, kPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                
                Group {
                    if appSession.activePack == 0 {
                        GameplayView(viewModel: viewModel)
                    } else {
                        DrinkingView(viewModel: viewModel)
                    }
                }
                .padding(.vertical, kPadding)
            }
        }
    }
    
    // MARK: - Button Actions
    
    private func draw() {
        Task {
            await viewModel.draw()
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
