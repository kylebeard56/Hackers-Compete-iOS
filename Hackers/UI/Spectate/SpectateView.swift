//
//  SpectateView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/17/23.
//

import AlertToast
import SwiftUI

public struct RefreshableScrollView<Content: View>: View {
    var content: Content
    var onRefresh: () -> Void

    public init(content: @escaping () -> Content, onRefresh: @escaping () -> Void) {
        self.content = content()
        self.onRefresh = onRefresh
    }

    public var body: some View {
        List {
            content
                .listRowSeparatorTint(.clear)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listStyle(.plain)
        .refreshable {
            onRefresh()
        }
    }
}

struct SpectateView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var roundSession: RoundSession
    @StateObject var viewModel = SpectateViewModel()
    
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case field }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Text("Spectate")
                    .font(.dmSans(size: 28, weight: .bold))
                    .foregroundColor(Color.systemBlack)
                    .alignCenter()

                BackButton( icon: .xmark, onTap: { dismiss() })
                    .alignTrailing()
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 0) {
                if viewModel.session.id.isEmpty {
                    spectateCode
                } else {
                    content
                }
            }
        }
        .environmentObject(roundSession)
        .padding(.vertical, 10)
        .background(Color.systemViewBackground)
        .onAppear() {
            if !roundSession.spectatorCode.isEmpty {
                viewModel.code = roundSession.spectatorCode
                Task { await viewModel.spectateSession() }
            } else if !deviceDefaults.spectatorCode.isEmpty {
                viewModel.code = deviceDefaults.spectatorCode
                Task { await viewModel.spectateSession() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                    self.focusedField = .field
                })
            }
        }
        .onChange(of: viewModel.currentHole, perform: { hole in
            Haptics.fire(.light)
            viewModel.computeHoleLogic(for: hole)
        })
        .onReceive(viewModel.$session, perform: { s in
            if s.id != "" {
                roundSession.spectatorCode = viewModel.code
            }
        })
    }
    
    // MARK: - Content
    
    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            SpectatorHoleTab(viewModel: viewModel)
            
            Spacer(minLength: 20)
            
            TabView(selection: $viewModel.currentHole) {
                ForEach(viewModel.holeRange, id: \.self) { i in
                    RefreshableScrollView {
                        self.spectatorView(for: i)
                    } onRefresh: {
                        Task {
                            viewModel.isRefreshing = true
                            await viewModel.spectateSession()
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            Spacer(minLength: 20)
            
            InfoBanner(
                icon: "f017",
                text: "Scores updated \(viewModel.session.lastUpdatedAt.iso.dateFromISO8601.relativeTimeAgo)",
                backgroundColor: colorScheme.superlightGray,
                onTap: {
                    Haptics.fire(.light)
                    Task { await viewModel.spectateSession() }
                }
            )
            .padding(.horizontal, 20)
            
            Spacer(minLength: 20)
            
            VStack(spacing: 20) {
                Divider()
                
                HStack {
                    Button(action: {
                        viewModel.stop()
                        Haptics.fire(.light)
                    }) {
                        Text("Stop")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemError)
                    }
                    
                    Spacer(minLength: 0)
                    
                    Button(action: {
                        Task { await viewModel.spectateSession() }
                        Haptics.fire(.light)
                    }) {
                        Text("Refresh")
                            .font(.dmSans(size: 17, weight: .medium))
                            .foregroundColor(Color.systemBlack)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .toast(isPresenting: $viewModel.isLoading, alert: { AlertToast.loader() })
    }
    
    @ViewBuilder private func spectatorView(for hole: Int) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                HStack {
                    Text("Thru \(viewModel.roundThru)")
                        .font(.dmSans(size: 15, weight: .bold))
                        .foregroundColor(Color.systemBlack)
                    
                    Spacer(minLength: 0)
                    
                    Text("This hole")
                        .foregroundColor(Color.systemGray)
                        .font(.dmSans(size: 13, weight: .medium))
                }
                
                ForEach(viewModel.players, id: \.self) { p in
                    SpectatorPlayerRow(viewModel: viewModel, player: .constant(p), hole: hole)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.systemCard)
            .border(Color.systemGray5, width: 3, cornerRadius: 12)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Join with spectate code
    
    private var spectateCode: some View {
        VStack(spacing: 20) {
            Group {
                Text("Enter the ")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
                + Text("spectator code")
                    .foregroundColor(Color.systemHackersYellow)
                    .font(.dmSans(size: 17, weight: .bold))
                + Text(" of another party to track their live round.")
                    .foregroundColor(Color.systemBlack)
                    .font(.dmSans(size: 17, weight: .regular))
            }
            .alignLeading()
            .padding(.horizontal, 20)
            
            InfoBanner(
                icon: "e03e",
                text: "The spectator code is the party code of the group you want to eavesdrop.",
                foregroundColor: Color.systemHackersYellow,
                backgroundColor: Color.systemHackersYellow.opacity(colorScheme.translucent)
            )
            .padding(.horizontal, 20)
            
            TextField("Spectator code", text: $viewModel.code)
                .font(.dmSans(size: 20, weight: .regular))
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.words)
                .submitLabel(.return)
                .focused($focusedField, equals: .field)
                .introspectTextField(customize: { $0.clearButtonMode = .whileEditing })
                .modifier(BorderedTextFieldModifier(isActive: focusedField == .field))
                .padding(.horizontal, 20)
            
            if viewModel.sessionNotFound {
                ErrorBanner(
                    title: "Spectator code not found",
                    subtitle: "Double-check the code you entered. Party codes are case sensitive.",
                    onTap: {
                        Haptics.fire(.light)
                        viewModel.sessionNotFound = false
                    }
                )
                .padding(.horizontal, 20)
            }
            
            Spacer(minLength: 0)
            
            VStack(spacing: 20) {
                Divider()
                
                BigButton(
                    title: "Spectate",
                    labelColor: .systemWhite,
                    buttonColor: .systemHackersYellow,
                    isDisabled: .constant(viewModel.code.isEmpty),
                    isLoading: $viewModel.isLoading
                )
                .onTapAsync {
                    await viewModel.spectateSession()
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct SpectateView_Previews: PreviewProvider {
    static var previews: some View {
        SpectateView()
    }
}
