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
    
    @StateObject var viewModel = JoinRoundViewModel()
    
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
                        .textFieldStyle(HackersTextFieldStyle())
                    
                    Button(action: {
                        print("todo: show camera to scan QR code")
                        Haptics.fire(.light)
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
        }
    }
}

#Preview {
    FindRoundView()
}
