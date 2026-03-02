//
//  DashboardHomeView.swift
//  Hackers
//
//  Home tab content for Dashboard.
//

import Flow
import SwiftUI

struct DashboardHomeView: View {
    @EnvironmentObject var appSession: AppSession
    @ObservedObject var viewModel: DashboardViewModel

    let palette: DesignPalette
    let sortedRounds: [Round]
    let activeRounds: [Round]
    let onSetHomeCourse: () -> Void
    let onRoundTap: (Round) -> Void
    let onRouteToLobby: (String) -> Void

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    navBarSpacer

                    if activeRounds.isPopulated {
                        activeRoundSection
                    }

                    homeCourseSection
                        .padding(.horizontal, 16)

                    if sortedRounds.isPopulated {
                        recentRoundsSection
                    }

                    Padding(.vertical, 120)
                }
            }

            homeNavBar
                .alignTop()
        }
    }

    private var navBarSpacer: some View {
        homeNavBar
            .disabled(true)
            .opacity(0)
            .accessibilityHidden(true)
    }

    private var homeNavBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Logo()
                .frame(height: 48)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var activeRoundSection: some View {
        VStack(spacing: 12) {
            Text("Active round".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()

            ForEach(activeRounds, id: \.self) { round in
                Button {
                    Haptics.fire(.light)
                    appSession.activeRoundID = round.id
                    if round.status == .live {
                        appSession.routeTo(.liveRound)
                    } else if round.status == .lobby {
                        appSession.routeTo(.lobby)
                    }
                } label: {
                    DashboardRoundTile(round: round, palette: palette, showDate: false)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var homeCourseSection: some View {
        if let homeCourse = viewModel.homeCourseName {
            Button {
                Haptics.fire(.light)
                viewModel.playAtHomeCourse { roundID in
                    onRouteToLobby(roundID)
                }
            } label: {
                HStack(spacing: 16) {
                    Icon(name: "f3c5", size: 24, weight: .regular)
                        .foregroundStyle(Color.accentGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Play at \(homeCourse)")
                            .fontStyle(kFontName, size: 17, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .lineLimit(1)
                        Text("Quick start at your home course")
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    Spacer(minLength: 0)

                    Icon(name: "chevron.right", size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral3)
                }
                .padding(16)
                .glassCardEffect()
            }
        } else {
            Button {
                Haptics.fire(.light)
                onSetHomeCourse()
            } label: {
                HStack(spacing: 16) {
                    Icon(name: "star", size: 24, weight: .regular)
                        .foregroundStyle(Color.accentGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set home course")
                            .fontStyle(kFontName, size: 17, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Text("Quick start rounds at your favorite course")
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                    }

                    Spacer(minLength: 0)

                    Icon(name: "chevron.right", size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral3)
                }
                .padding(16)
                .glassCardEffect()
            }
        }
    }

    @ViewBuilder
    private var recentRoundsSection: some View {
        let recent = Array(sortedRounds.prefix(3))
        VStack(spacing: 12) {
            Text("Recent rounds".uppercased())
                .fontStyle(kFontName, size: 14, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignLeading()

            ForEach(recent, id: \.self) { round in
                Button {
                    Haptics.fire(.light)
                    onRoundTap(round)
                } label: {
                    DashboardRoundTile(round: round, palette: palette)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
