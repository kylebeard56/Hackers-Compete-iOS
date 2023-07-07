//
//  RoundSetupView.swift
//  Hackers
//
//  Created by Kyle Beard on 6/18/23.
//

import SwiftUI

struct RoundSetupView: View {
    @EnvironmentObject var appSession: AppSession
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    holeCount
                    startingSide
                    startingHole
                    Spacer(minLength: 0)
                }
            }
            
            VStack(spacing: 20) {
                Divider()
                
                BigButton(
                    title: "Next",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersGreen,
                    isDisabled: .false,
                    isLoading: .false,
                    onTap: { appSession.goToPlayers() }
                )
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 20)
        .background(Color.systemViewBackground)
        .environmentObject(appSession)
        .navigationTitle("Setup your round")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                BackButton(onTap: { dismiss() })
            }
        }
        .introspectNavigationController(customize: { c in
            c.navigationBar.titleTextAttributes = [.font: UIFont.dmSans(size: 28, weight: .bold)]
        })
    }
    
    // MARK: - Subviews
    
    private var holeCount: some View {
        VStack(spacing: 20) {
            Group {
                Text("How many ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("holes")
                    .foregroundColor(Color.systemHackersGreen)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" are you playing?")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            
            PillDivider()
            
            HStack(spacing: 20) {
                holeCountButton(for: 9)
                holeCountButton(for: 18)
            }
        }
        .padding(.horizontal, 20)
    }

    private var startingSide: some View {
        VStack(spacing: 20) {
            Group {
                Text("What ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("side")
                    .foregroundColor(Color.systemHackersGreen)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" are you \(appSession.numberOfHoles == 18 ? "starting on" : "playing")?")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            
            PillDivider()
            
            HStack(spacing: 20) {
                sideButton(for: "Front")
                sideButton(for: "Back")
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var startingHole: some View {
        VStack(spacing: 20) {
            Group {
                Text("Which ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("hole")
                    .foregroundColor(Color.systemHackersGreen)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" will you start on?")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .padding(.horizontal, 20)
            
            PillDivider()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    if appSession.startingSide == "front" {
                        ForEach(1...9, id: \.self) { i in
                            holeButton(for: i)
                                .padding(.leading, i == 1 ? 20 : 0)
                                .padding(.trailing, i == 9 ? 20 : 0)
                        }
                    } else {
                        ForEach(10...18, id: \.self) { i in
                            holeButton(for: i)
                                .padding(.leading, i == 10 ? 20 : 0)
                                .padding(.trailing, i == 18 ? 20 : 0)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    // MARK: - Buttons
    
    @ViewBuilder private func holeCountButton(for value: Int) -> some View {
        let isSelected: Bool = appSession.numberOfHoles == value
        Button(action: {
            appSession.numberOfHoles = value
            Haptics.fire(.light)
        }) {
            Text("\(value)")
                .font(.dmSans(size: 40, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? Color.systemHackersGreen : Color.systemBlack)
                .alignCenter()
                .alignMiddle()
                .background(isSelected ? Color.systemHackersGreen.opacity(colorScheme.translucent) : Color.systemCard)
                .aspectRatio(CGSize(width: 1, height: 1), contentMode: .fill)
                .border(
                    isSelected ? Color.systemHackersGreen : colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
                    width: isSelected ? 6 : 3,
                    cornerRadius: 20
                )
                .cornerRadius(20)
        }
    }
    
    @ViewBuilder private func sideButton(for value: String) -> some View {
        let isSelected: Bool = appSession.startingSide == value.lowercased()
        Button(action: {
            appSession.startingSide = value.lowercased()
            Haptics.fire(.light)
        }) {
            Text("\(value)")
                .font(.dmSans(size: 22, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? Color.systemHackersGreen : Color.systemBlack)
                .alignCenter()
                .alignMiddle()
                .background(isSelected ? Color.systemHackersGreen.opacity(colorScheme.translucent) : Color.systemCard)
                .frame(height: 64)
                .border(
                    isSelected ? Color.systemHackersGreen : colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
                    width: isSelected ? 6 : 3,
                    cornerRadius: 12
                )
                .cornerRadius(12)
        }
    }
    
    @ViewBuilder private func holeButton(for value: Int) -> some View {
        let isSelected: Bool = appSession.startingHole == value
        Button(action: {
            appSession.startingHole = value
            Haptics.fire(.light)
        }) {
            Text("\(value)")
                .font(.dmSans(size: 22, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? Color.systemHackersGreen : Color.systemBlack)
                .alignCenter()
                .alignMiddle()
                .background(isSelected ? Color.systemHackersGreen.opacity(colorScheme.translucent) : Color.systemCard)
                .frame(width: 64, height: 64)
                .border(
                    isSelected ? Color.systemHackersGreen : colorScheme.isLight ? Color.systemGray5 : Color.systemGray3,
                    width: isSelected ? 6 : 3,
                    cornerRadius: 12
                )
                .cornerRadius(12)
        }
    }
}

struct RoundSetupView_Previews: PreviewProvider {
    static var previews: some View {
        RoundSetupView()
    }
}
