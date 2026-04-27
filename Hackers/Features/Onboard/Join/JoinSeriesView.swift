//
//  JoinSeriesView.swift
//  Hackers
//

import SwiftUI

struct JoinSeriesView: View, Loggable {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var appSession: AppSession
    @ObservedObject var viewModel: JoinSeriesViewModel

    var onDismiss: Callback? = nil

    @State private var showMemberSelector = false
    @State private var showAuthTile = false

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var activeMembers: [SeriesMember] {
        viewModel.members.filter(\.isActive)
    }

    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showMemberSelector) {
            ClaimSeriesMemberView(viewModel: viewModel)
                .environmentObject(appSession)
        }
        .sheet(isPresented: $showAuthTile) {
            AuthTile(onAuth: { newlyCreated in
                await appSession.syncUserState()

                if newlyCreated {
                    if viewModel.newClaimedPlayer.exists {
                        await viewModel.claimNewPlayerAndEnterSeries()
                    } else {
                        await viewModel.claimOfflineMember()
                    }
                } else {
                    await viewModel.overrideClaimWithPrimaryPlayer()
                }
                showAuthTile = false
            }, onContinueAsGuest: {
                if viewModel.newClaimedPlayer.exists {
                    await viewModel.claimNewPlayerAndEnterSeries()
                } else {
                    await viewModel.continueAsGuest()
                }
                showAuthTile = false
            })
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
    }

    private var header: some View {
        ZStack {
            NavButton(icon: "f053", onTap: { dismiss() })
                .alignLeading()

            Text("Join series?")
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .alignCenter()

            NavButton(icon: "f00d", onTap: {
                onDismiss?()
            })
            .alignTrailing()
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Line()

            PrimaryButton(
                appearance: .fill,
                title: "Join",
                labelColor: palette.backgroundColor,
                buttonColor: palette.foregroundColor,
                iconSize: 24,
                isDisabled: .constant(viewModel.claimedMember == nil && viewModel.newClaimedPlayer == nil),
                isLoading: .false,
                onTapAsync: {
                    if await AppData.shared.user.doesNotExist {
                        showAuthTile = true
                    } else if viewModel.isPlayerLocked {
                        await viewModel.enterSeriesIfAlreadyMember()
                    } else {
                        await viewModel.claimOfflineMember()
                    }
                }
            )
            .padding(.horizontal, 16)
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Spacer().frame(height: 0)

                Text("Series details")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .alignLeading()

                seriesInformation
                    .outlineEffect(for: palette)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Text("Pick your player")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .alignLeading()

                    Spacer(minLength: 0)

                    if viewModel.claimedMember == nil && viewModel.newClaimedPlayer == nil {
                        Chip.required
                    } else {
                        Chip.requiredConfirmation
                    }
                }

                memberSelectionDropdown

                if viewModel.isPlayerLocked {
                    Text("Your player account has been linked to this series.")
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private var seriesInformation: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Text("League")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(viewModel.series?.name ?? "—")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Organizer")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(viewModel.commissionerName)
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Status")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text(viewModel.series.map { $0.status.rawValue.capitalized } ?? "—")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)

            HStack(spacing: 16) {
                Text("Members")
                    .foregroundStyle(Color.neutral)
                Spacer()
                Text("\(activeMembers.count)")
                    .foregroundStyle(palette.foregroundColor)
            }
            .fontStyle(kFontName, size: 15, weight: .medium)
        }
    }

    private var memberSelectionDropdown: some View {
        Button(action: {
            Haptics.fire(.light)
            showMemberSelector = true
        }) {
            HStack {
                if let member = viewModel.claimedMember {
                    Text(member.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.foregroundPrimary)
                } else if let newPlayer = viewModel.newClaimedPlayer {
                    Text(newPlayer.name.fullName)
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.foregroundPrimary)
                } else {
                    Text("Select your player")
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }

                Spacer()

                if !viewModel.isPlayerLocked {
                    Icon(name: "f078", size: 12, weight: .solid)
                        .foregroundStyle(Color.neutral3)
                } else {
                    Icon(name: "f00c", size: 12, weight: .solid)
                        .foregroundStyle(Color.accentGreen)
                }
            }
            .padding(16)
            .border(Color.neutral5, width: 1.5, cornerRadius: 10)
        }
        .disabled(viewModel.isPlayerLocked)
    }
}

// MARK: - Claim roster member

struct ClaimSeriesMemberView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var appSession: AppSession
    @ObservedObject var viewModel: JoinSeriesViewModel

    @State private var showAddNew = false
    @State private var showAuthTile = false
    @State private var isLoggingIn = false

    private var unclaimed: [SeriesMember] {
        viewModel.members.filter { $0.isActive && $0.isOffline }
    }

    private var claimed: [SeriesMember] {
        viewModel.members.filter { $0.isActive && !$0.isOffline }
    }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        StickyScrollView(
            header: { header },
            content: { content },
            footer: { footer },
            onScroll: { _ in }
        )
        .onChange(of: viewModel.completeFlow) { _, done in
            if done { dismiss() }
        }
        .sheet(isPresented: $showAddNew) {
            NewOfflinePlayerView { name in
                var player = Player(name: name)
                player.needsToBeCreated = true
                viewModel.newClaimedPlayer = player
                showAddNew = false
            }
        }
        .sheet(isPresented: $showAuthTile) {
            AuthTile(
                title: "Login or sign up",
                subtitle: "Sign in for free to link this series to a new or existing player account.",
                allowGuests: false,
                onAuth: { _ in
                    showAuthTile = false
                    isLoggingIn = true
                    await appSession.syncUserState()
                    await viewModel.fetchPrimaryPlayer()
                    isLoggingIn = false
                    if viewModel.isPlayerLocked { dismiss() }
                }
            )
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Text("Claim your player")
                    .fontStyle(kFontName, size: 24, weight: .semibold)
                    .foregroundStyle(Color.foregroundPrimary)
                    .alignLeading()

                Spacer(minLength: 0)

                NavButton(icon: "f00d", onTap: { dismiss() })
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
    }

    private var footer: some View {
        VStack(spacing: 16) {
            Line()

            HStack(spacing: 16) {
                if let newPlayer = viewModel.newClaimedPlayer {
                    PrimaryButton(
                        appearance: .fill,
                        title: "Continue as \(newPlayer.name.fullName)",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: { dismiss() }
                    )
                } else if let player = viewModel.primaryPlayer {
                    let matchingOfflineMember = viewModel.matchingOfflineMember(for: player)
                    PrimaryButton(
                        appearance: .fill,
                        title: matchingOfflineMember.map { "Claim \($0.name.fullName)" } ?? "Add \(player.name.fullName)",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .false,
                        isLoading: .false,
                        onTapAsync: { await viewModel.addPrimaryPlayerToSeries() }
                    )
                } else {
                    PrimaryButton(
                        appearance: .fill,
                        title: "Login",
                        labelColor: palette.foregroundColor,
                        buttonColor: palette.buttonColor,
                        theme: palette.theme,
                        isDisabled: .false,
                        isLoading: $isLoggingIn,
                        onTap: {
                            showAuthTile = true
                        }
                    )
                    PrimaryButton(
                        appearance: .fill,
                        title: "Add player",
                        labelColor: palette.backgroundColor,
                        buttonColor: palette.foregroundColor,
                        theme: palette.theme,
                        isDisabled: .false,
                        isLoading: .false,
                        onTap: {
                            showAddNew = true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                if unclaimed.isPopulated {
                    Text("\(unclaimed.count) available to claim")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.accentPurple)
                        .alignLeading()

                    ForEach(unclaimed.sorted { $0.name.fullName < $1.name.fullName }, id: \.id) { m in
                        row(for: m)
                        Line()
                    }
                }

                Spacer().frame(height: 0)

                if claimed.isPopulated {
                    Text("\(claimed.count) already linked")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()

                    ForEach(claimed.sorted { $0.name.fullName < $1.name.fullName }, id: \.id) { m in
                        row(for: m)
                        Line()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func row(for member: SeriesMember) -> some View {
        HStack(spacing: 12) {
            Text(member.name.fullName)
                .fontStyle(kFontName, size: 17, weight: .medium)
                .foregroundStyle(Color.foregroundPrimary)

            Spacer(minLength: 0)

            if member.isOffline {
                Button {
                    Haptics.fire(.light)
                    viewModel.claimedMember = member
                    dismiss()
                } label: {
                    Chip(
                        text: "Claim",
                        size: .small,
                        style: .fill,
                        foreground: Color.accentPurple,
                        background: Color.neutral6
                    )
                }
            }
        }
    }
}
