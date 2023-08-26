//
//  ContinueRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/21/23.
//

import SwiftUI

struct ContinueRoundView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSession: Session?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                    .alignTop()
                
                VStack(spacing: 20) {
                    Divider()
                    
                    BigButton(
                        title: "Continue",
                        labelColor: .systemWhite,
                        buttonColor: .systemHackersGreen,
                        isDisabled: .constant(selectedSession == nil),
                        isLoading: $appSession.isJoiningWithPartyCode
                    )
                    .onTap {
                        if let selectedSession {
                            appSession.startRound(for: selectedSession)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 10)
            .navigationTitle("Continue round")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BackButton( icon: .xmark, onTap: { dismiss() })
                }
            }
            .introspectNavigationController(customize: { c in
                c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 28, weight: .bold)]
            })
        }
        .environmentObject(appSession)
        .background(Color.systemViewBackground)
        .padding(.top, 10)
    }
    
    private var content: some View {
        VStack(spacing: 20) {
            Text("Pick which round to continue playing:")
                .foregroundColor(Color.systemBlack)
                .font(.dmSans(size: 17, weight: .regular))
                .alignLeading()
                .padding(.horizontal, 20)
            
            InfoBanner(
                text: "Rounds are only active for 24 hours before they become archived.",
                foregroundColor: Color.systemHackersGreen,
                backgroundColor: Color.systemHackersGreen.opacity(colorScheme.translucent)
            )
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(appSession.currentSessions, id: \.self) { session in
                        tile(for: session)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    @ViewBuilder private func tile(for s: Session) -> some View {
        let isSelected: Bool = selectedSession == s
        Button(action: {
            selectedSession = isSelected ? nil : s
            Haptics.fire(.light)
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.systemHackersGreen.opacity(colorScheme.translucent) : Color.systemGray6)
                        .frame(width: 48, height: 48)
                    AwesomeImage(
                        rawIcon: isSelected ? "f00c".unicode : "f450".unicode,
                        style: .regular,
                        size: 24,
                        color: isSelected ? Color.systemHackersGreen : Color.systemBlack
                    )
                }
                
                VStack(spacing: 4) {
                    Text(s.playerNames)
                        .foregroundColor(isSelected ? Color.systemHackersGreen : Color.systemBlack)
                        .font(.dmSans(size: 20, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .alignLeading()

                    HStack(spacing: 10) {
                        Text(s.numberOfHolesPlayed == 0 ? "No scores yet" : "Thru \(s.numberOfHolesPlayed)")
                            .foregroundColor(Color.systemGray)
                            .font(.dmSans(size: 13, weight: .medium))
                        
                        Circle()
                            .fill(Color.systemGray3)
                            .frame(width: 4, height: 4)
                        
                        Text("Started at \(s.roundStartingTime)")
                            .foregroundColor(Color.systemGray)
                            .font(.dmSans(size: 13, weight: .medium))
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(
                isSelected ? Color.systemHackersGreen : colorScheme.lightGray,
                width: isSelected ? 6 : 3,
                cornerRadius: 12
            )
            .cornerRadius(12)
        }
    }
}

struct ContinueRoundView_Previews: PreviewProvider {
    static var appSession: AppSession = AppSession()
    static var view: some View {
        ContinueRoundView()
            .onAppear() {
                appSession.currentSessions = [kSession, kSession, kSession]
                appSession.players = kSession.players.compactMap({ Player(session: $0) })
            }
            .environmentObject(appSession)
    }
    static var previews: some View {
        view.holisticPreview()
    }
}
