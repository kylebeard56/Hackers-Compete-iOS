//
//  SpectateView.swift
//  Hackers
//
//  Created by Kyle Beard on 7/17/23.
//

import AlertToast
import SwiftUI

struct RefreshableScrollView<Content: View>: View {
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
    
    // TODO: Read below
    /// 1. RoundSession needs spectator code to load on command.
    /// 2. Customize leaderboard to say "Unscored" vs "Enter score"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.session.id.isEmpty {
                    spectateCode
                } else {
                    content
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            .navigationTitle("Spectate")
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
        .environmentObject(roundSession)
        .background(Color.systemViewBackground)
        .padding(.top, 10)
        .onAppear() {
            if roundSession.spectatorCode.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: {
                    self.focusedField = .field
                })
            } else {
                viewModel.code = roundSession.spectatorCode
                Task { await viewModel.spectateSession() }
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
        VStack(spacing: 20) {
            TabView(selection: $viewModel.currentHole) {
                ForEach(viewModel.holeRange, id: \.self) { i in
                    self.spectatorView(for: i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.linear(duration: 0.2), value: viewModel.currentHole)
            
            Spacer(minLength: 0)
            
            InfoBanner(
                icon: "f017",
                text: "Last updated \(viewModel.session.lastUpdatedAt.iso.dateFromISO8601.relativeTimeAgo).",
                backgroundColor: colorScheme.superlightGray,
                onTap: {
                    Haptics.fire(.light)
                    Task { await viewModel.spectateSession() }
                }
            )
            .padding(.horizontal, 20)
            
            VStack(spacing: 20) {
                Divider()
                
                BigButton(
                    title: "Stop spectating",
                    labelColor: .systemWhite,
                    buttonColor: .systemError,
                    isDisabled: .false,
                    isLoading: .false
                )
                .onTapAsync {
                    await viewModel.spectateSession()
                }
                .padding(.horizontal, 20)
            }
        }
        .toast(isPresenting: $viewModel.isLoading, alert: { AlertToast.loader() })
    }
    
    @ViewBuilder private func spectatorView(for hole: Int) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    VStack(spacing: 2) {
                        Text("Hole \(hole)")
                            .font(.dmSans(size: 20, weight: .bold))
                            .foregroundColor(Color.systemBlack)
                            .alignLeading()
                        
                        HStack(spacing: 10) {
                            Text("Thru \(viewModel.roundThru)")
                                .foregroundColor(Color.systemGray)
                                .font(.dmSans(size: 13, weight: .medium))
                            
                            Circle()
                                .fill(Color.systemGray3)
                                .frame(width: 4, height: 4)
                            
                            Text("Playing \(viewModel.numberOfHoles)")
                                .foregroundColor(Color.systemGray)
                                .font(.dmSans(size: 13, weight: .medium))
                            
                            Spacer(minLength: 0)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                
                ForEach(viewModel.players, id: \.self) { p in
                    LeaderboardPlayerRow(
                        player: .constant(p),
                        hole: hole,
                        isSpectating: true
                    )
                }
                
                Button(action: {
                    viewModel.currentHole = viewModel.lastScoredHole
                    Haptics.fire(.light)
                }) {
                    HStack(spacing: 10) {
                        AwesomeImage(rawIcon: "e3d6".unicode, style: .regular, size: 15, color: Color.systemBlack)
                        Text("Jump to current hole")
                            .foregroundColor(Color.systemBlack)
                            .font(.dmSans(size: 13, weight: .medium))
                            .multilineTextAlignment(.leading)
                            .alignLeading()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.systemGray6)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
        }
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
