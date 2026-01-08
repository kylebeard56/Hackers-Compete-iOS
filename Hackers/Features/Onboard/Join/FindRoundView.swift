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
    
    @StateObject var appSession: AppSession
    @StateObject var viewModel = JoinRoundViewModel()
    
    @State private var showScanner = false
    @State private var errorText: String? = "This is a sample"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        Text("Join round")
                            .fontStyle(.poppins, size: 24, weight: .semibold)
                            .foregroundStyle(Color.foregroundPrimary)
                            .alignLeading()

                        Spacer(minLength: 0)

                        NavButton(icon: "f00d", onTap: { dismiss() })
                    }
                    
                    Text("Enter the share code to join your round:")
                        .fontStyle(.poppins, size: 15, weight: .medium)
                        .foregroundStyle(Color.neutral)
                        .alignLeading()
                }
                
                HStack(spacing: 12) {
                    TextField("Enter share code", text: $viewModel.code)
                        .foregroundStyle(Color.foregroundPrimary)
                        .textInputAutocapitalization(.characters)
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
            }
            .padding(16)
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button { dismiss() } label: {
//                        Icon(name: "xmark", size: 17)
//                            .foregroundStyle(Color.systemBlack)
//                    }
//                }
//            }
            .navigationDestination(isPresented: $viewModel.route) {
                JoinRoundView(viewModel: viewModel)
            }
            .sheet(isPresented: $showScanner) {
                cameraView
            }
        }
    }
    
    private var cameraView: some View {
        ZStack {
            QRScannerView { result in
                switch result {
                case .success(let url):
                    printPretty(url)
                    if let roundID = url.extractRoundID {
                        appSession.joinRoundID = roundID
                        viewModel.route = true
                        showScanner = false
                    } else {
                        let str = url.absoluteString
                        errorText = "The round ID is missing from this link."
                        addBreadcrumb(.warning, .joinRound, "Failed to fetch round ID from QR Code for URL \(str)")
                    }
                case .failure(let error):
                    errorText = error.description
                    addBreadcrumb(.warning, .joinRound, "Failed to scan QR code", error)
                }
            }
            
            RoundedRectangle(cornerRadius: 52)
                .strokeBorder(Color.accentYellow, lineWidth: 4)
                .frame(width: 300, height: 300)
            
            if let text = errorText {
                ErrorBanner(
                    title: "Scan error",
                    subtitle: text,
                    color: .systemError,
                    background: .systemError.opacity(0.7),
                    material: .ultraThinMaterial,
                    onTap: { errorText = nil }
                )
                .padding(.horizontal, 20)
                .alignBottom()
            }
            
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
}
