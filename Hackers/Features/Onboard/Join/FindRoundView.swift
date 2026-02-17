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
    @StateObject var viewModel = JoinRoundViewModel()
    
    var onJoin: Callback? = nil
    
    @FocusState private var focus: Bool
    
    @State private var showScanner = false
    @State private var errorText: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        Text("Join round")
                            .fontStyle(kFontName, size: 24, weight: .semibold)
                            .foregroundStyle(Color.foregroundPrimary)
                            .alignLeading()

                        Spacer(minLength: 0)

                        NavButton(icon: "f00d", onTap: { dismiss() })
                    }
                    
                    Text("Enter the share code to join your round:")
                        .fontStyle(kFontName, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
                
                HStack(spacing: 12) {
                    TextField("Enter share code", text: $viewModel.code)
                        .foregroundStyle(Color.foregroundPrimary)
                        .textInputAutocapitalization(.characters)
                        .focused($focus)
                        .borderedContentStyle()
                    
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
                
                if let e = viewModel.findRoundError {
                    ErrorBanner(
                        title: "Round not found",
                        subtitle: e.rawValue,
                        onTap: { viewModel.findRoundError = nil }
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
                    isLoading: $viewModel.isLoading,
                    onTap: {
                        Task { await viewModel.findRound() }
                    }
                )
                .padding(.bottom, focus ? 16 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .task {
                // 1. If the app session code is already set, fetch it and try to find round.
                if let code = appSession.shareCode {
                    viewModel.code = code
                    await viewModel.findRound()
                }
                
                // 2. Set the round session reference class for view model business logic
                viewModel.setRoundSession(roundSession)
            }
            .onReceive(viewModel.$completeFlow, perform: { value in
                if value {
                    // 1. Check if the ephemeral ID exists -> user is continuing as guest
                    if let id = viewModel.ephemeralParticipantID {
                        appSession.ephemeralParticipantID = id
                    }
                    
                    // 2. Callback to kickoff round routing
                    onJoin?()
                }
            })
            .navigationDestination(isPresented: $viewModel.route) {
                JoinRoundView(viewModel: viewModel) {
                    dismiss()
                }
            }
            .sheet(isPresented: $showScanner) {
                cameraView
            }
        }
        .environmentObject(appSession)
    }
    
    private var cameraView: some View {
        ZStack {
            QRScannerView { result in
                switch result {
                case .success(let url):
                    printPretty(url)
                    if let shareCode = url.extractedShareCode {
                        addBreadcrumb(message: "Share code found for round from QR code as \(shareCode)")
                        showScanner = false
                        viewModel.code = shareCode
                        Task { await viewModel.findRound() }
                    } else {
                        errorText = "The share code to join a round is missing from this link."
                        addBreadcrumb(
                            level: .warning,
                            message: "Failed to fetch round ID from QR Code for URL",
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
}

#Preview {
    FindRoundView(appSession: .init())
        .environmentObject(AppSession())
}
