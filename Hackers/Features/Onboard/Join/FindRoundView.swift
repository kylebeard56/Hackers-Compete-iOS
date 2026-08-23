//
//  FindRoundView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/28/25.
//

import SwiftUI

struct FindRoundView: View, Loggable {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @EnvironmentObject var appSession: AppSession
    @EnvironmentObject var roundSession: RoundSession

    @StateObject private var joinRoundViewModel = JoinRoundViewModel()
    @StateObject private var joinSeriesViewModel = JoinSeriesViewModel()

    var onJoin: Callback? = nil

    @FocusState private var focus: Bool

    @State private var showScanner = false
    @State private var errorText: String? = nil
    @State private var didTrackScreenView = false

    @State private var ambiguousRound: Round?
    @State private var ambiguousSeries: Series?
    @State private var showJoinTargetPicker = false

    @State private var genericLookupError: String?

    private var combinedLoading: Binding<Bool> {
        Binding(
            get: { joinRoundViewModel.isLoading || joinSeriesViewModel.isLoading },
            set: { _ in }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        Text("Join round or series")
                            .fontStyle(kFontName, size: 24, weight: .semibold)
                            .foregroundStyle(Color.foregroundPrimary)
                            .alignLeading()

                        Spacer(minLength: 0)

                        NavButton(icon: "f00d", onTap: { dismiss() })
                    }

                    Text("Enter your round or league code, or scan a QR link from your host.")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }

                HStack(spacing: 12) {
                    TextField("Enter code", text: $joinRoundViewModel.code)
                        .foregroundStyle(Color.foregroundPrimary)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .focused($focus)
                        .borderedContentStyle()
                        .onChange(of: joinRoundViewModel.code) { _, newValue in
                            joinSeriesViewModel.code = newValue
                        }

                    Button(action: {
                        Haptics.fire(.light)
                        showScanner = true
                    }) {
                        Icon(name: "qrcode.viewfinder", size: 17, weight: .semibold)
                            .foregroundStyle(Color.foregroundPrimary)
                            .padding()
                            .background(Color.neutral6)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let e = joinRoundViewModel.findRoundError {
                    ErrorBanner(
                        title: "Round not found",
                        subtitle: e.rawValue,
                        onTap: { joinRoundViewModel.findRoundError = nil }
                    )
                }

                if let e = joinSeriesViewModel.findSeriesError {
                    ErrorBanner(
                        title: "Series not found",
                        subtitle: e.rawValue,
                        onTap: { joinSeriesViewModel.findSeriesError = nil }
                    )
                }

                if let g = genericLookupError {
                    ErrorBanner(
                        title: "Nothing matched",
                        subtitle: g,
                        onTap: { genericLookupError = nil }
                    )
                }

                Spacer(minLength: 0)

                PrimaryButton(
                    appearance: .fill,
                    title: "Continue",
                    labelColor: .white,
                    buttonColor: .black,
                    iconSize: 24,
                    isDisabled: .false,
                    isLoading: combinedLoading,
                    onTap: {
                        Task { await submitLookup() }
                    }
                )
                .addPostHogLabel("Join with code CTA")
                .padding(.bottom, focus ? 16 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .task {
                joinRoundViewModel.setRoundSession(roundSession)
                await consumePendingJoinIfNeeded()
            }
            .onReceive(joinRoundViewModel.$completeFlow, perform: { value in
                guard value else { return }
                if let id = joinRoundViewModel.ephemeralParticipantID {
                    appSession.ephemeralParticipantID = id
                }
                appSession.isSpectating = joinRoundViewModel.isSpectating
                appSession.activeRoundID = joinRoundViewModel.round?.id
                let shouldReplace = appSession.path.count > 1
                switch joinRoundViewModel.round?.status {
                case .live:
                    appSession.routeTo(.liveRound, replacingCurrent: shouldReplace)
                default:
                    appSession.routeTo(.lobby, replacingCurrent: shouldReplace)
                }
                onJoin?()
            })
            .onReceive(joinSeriesViewModel.$completeFlow, perform: { value in
                guard value else { return }
                guard let seriesID = joinSeriesViewModel.series?.id else { return }
                appSession.activeSeriesID = seriesID
                let shouldReplace = appSession.path.count > 1
                appSession.routeTo(.series(id: seriesID), replacingCurrent: shouldReplace)
                Task { await appSession.loadSeries() }
                onJoin?()
            })
            .navigationDestination(isPresented: $joinRoundViewModel.route) {
                JoinRoundView(viewModel: joinRoundViewModel) {
                    dismiss()
                }
            }
            .navigationDestination(isPresented: $joinSeriesViewModel.route) {
                JoinSeriesView(viewModel: joinSeriesViewModel) {
                    dismiss()
                }
            }
            .sheet(isPresented: $showScanner) {
                cameraView
            }
            .alert("Join using this code", isPresented: $showJoinTargetPicker) {
                Button("Join league") {
                    Task { await resolveAmbiguity(pickSeries: true) }
                }
                Button("Join round") {
                    Task { await resolveAmbiguity(pickSeries: false) }
                }
                Button("Cancel", role: .cancel) {
                    ambiguousRound = nil
                    ambiguousSeries = nil
                }
            } message: {
                Text("We found both a league and a round with this code. Which do you want to join?")
            }
        }
        .environmentObject(appSession)
        .captureScreen("join_unified")
        .task {
            guard !didTrackScreenView else { return }
            didTrackScreenView = true
            addEvent("join.lookup_viewed")
        }
    }

    private var cameraView: some View {
        ZStack {
            QRScannerView { result in
                switch result {
                case .success(let url):
                    if let payload = url.joinDeepLinkPayload {
                        showScanner = false
                        switch payload {
                        case .roundID(let token):
                            joinRoundViewModel.code = token
                            joinSeriesViewModel.code = token
                            Task { await joinRoundViewModel.findRound() }
                        case .seriesID(let token):
                            joinRoundViewModel.code = token
                            joinSeriesViewModel.code = token
                            Task { await joinSeriesViewModel.findSeries() }
                        case .legacyCode(let token):
                            joinRoundViewModel.code = token
                            joinSeriesViewModel.code = token
                            Task { await performFreeformLookup(token: token) }
                        }
                    } else {
                        errorText = "This QR code does not contain a valid Hackers join link."
                        addBreadcrumb(
                            level: .warning,
                            message: "Failed to parse join URL",
                            parameters: ["URL": url.absoluteString]
                        )
                    }
                case .failure(let error):
                    errorText = error.description
                    addBreadcrumb(level: .warning, message: "Failed to scan QR code", error: error)
                }
            }

            RoundedRectangle(cornerRadius: 52)
                .strokeBorder(Color.accentYellow, lineWidth: 4)
                .frame(width: 300, height: 300)

            if let text = errorText {
                ErrorBanner(
                    title: "Scan error",
                    subtitle: text,
                    color: .white,
                    background: .systemError.opacity(0.8),
                    onTap: { errorText = nil }
                )
                .padding(.horizontal, 20)
                .alignBottom()
            }

            Text("Scan QR Code")
                .fontStyle(kFontName, size: 20, weight: .semibold)
                .foregroundStyle(.white)
                .alignTop()
                .padding(.top, 24)

            NavButton(
                style: .glass,
                icon: "f00d",
                background: .clear,
                onTap: { showScanner = false }
            )
            .alignTop()
            .alignTrailing()
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
    }

    @MainActor
    private func consumePendingJoinIfNeeded() async {
        if let link = appSession.pendingJoinLink {
            appSession.pendingJoinLink = nil
            switch link {
            case .round(let token):
                joinRoundViewModel.code = token
                joinSeriesViewModel.code = token
                await joinRoundViewModel.findRound()
            case .series(let token):
                joinRoundViewModel.code = token
                joinSeriesViewModel.code = token
                await joinSeriesViewModel.findSeries()
            case .freeform(let token):
                joinRoundViewModel.code = token
                joinSeriesViewModel.code = token
                await performFreeformLookup(token: token)
            }
        } else if let legacy = appSession.shareCode {
            appSession.shareCode = nil
            joinRoundViewModel.code = legacy
            joinSeriesViewModel.code = legacy
            await performFreeformLookup(token: legacy)
        }
    }

    @MainActor
    private func submitLookup() async {
        genericLookupError = nil
        joinRoundViewModel.findRoundError = nil
        joinSeriesViewModel.findSeriesError = nil
        joinSeriesViewModel.code = joinRoundViewModel.code
        await performFreeformLookup(token: joinRoundViewModel.code)
    }

    @MainActor
    private func performFreeformLookup(token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isPopulated else { return }

        genericLookupError = nil
        joinRoundViewModel.findRoundError = nil
        joinSeriesViewModel.findSeriesError = nil

        joinRoundViewModel.isLoading = true
        joinSeriesViewModel.isLoading = true
        defer {
            joinRoundViewModel.isLoading = false
            joinSeriesViewModel.isLoading = false
        }

        let roundRes = await FirebaseService.shared.resolveRound(byToken: trimmed)
        let seriesRes = await FirebaseService.shared.resolveSeries(byToken: trimmed)

        switch (roundRes, seriesRes) {
        case (.success(let round), .success(let series)):
            ambiguousRound = round
            ambiguousSeries = series
            showJoinTargetPicker = true
        case (.success(let round), .failure):
            do {
                try await joinRoundViewModel.applyLoadedRound(round)
            } catch {
                joinRoundViewModel.findRoundError = .unknown
            }
        case (.failure, .success(let series)):
            await joinSeriesViewModel.applyLoadedSeries(series)
        case (.failure, .failure):
            genericLookupError = "No round or league matched that code."
        }
    }

    @MainActor
    private func resolveAmbiguity(pickSeries: Bool) async {
        guard let round = ambiguousRound, let series = ambiguousSeries else { return }
        showJoinTargetPicker = false
        ambiguousRound = nil
        ambiguousSeries = nil

        if pickSeries {
            await joinSeriesViewModel.applyLoadedSeries(series)
        } else {
            do {
                try await joinRoundViewModel.applyLoadedRound(round)
            } catch {
                joinRoundViewModel.findRoundError = .unknown
            }
        }
    }
}

#Preview {
    FindRoundView()
        .environmentObject(AppSession())
        .environmentObject(RoundSession())
}
