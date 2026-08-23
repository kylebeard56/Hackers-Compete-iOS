//
//  AI.swift
//  Hackers
//
//  Created by Kyle Beard on 8/14/25.
//

import Flow
import SwiftUI
import MapKit

// MARK: - Models
struct LobbyCourse: Identifiable, Equatable {
    static func == (lhs: LobbyCourse, rhs: LobbyCourse) -> Bool {
        lhs.id == rhs.id
    }
    
    let id = UUID()
    var clubName: String
    var LobbyCourseName: String
    var par: Int
    var yardage: Int
    var holes: Int
    var location: CLLocationCoordinate2D?

    var displayName: String { LobbyCourseName.isEmpty ? clubName : "\(clubName) — \(LobbyCourseName)" }
}

enum LobbyGameFormat: String, CaseIterable, Identifiable {
    case strokePlay = "Stroke Play"
    case matchPlay = "Match Play"
    case captainsChoice = "Captain's Choice"
    case skins = "Skins"
    case scramble = "Scramble"

    var id: String { rawValue }
}

struct LobbyPlayer: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var isHost: Bool = false

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

// MARK: - Root View
struct GameLobbyView: View {
    // Inputs
    @State var LobbyCourse: LobbyCourse
    @State var LobbyPlayers: [LobbyPlayer]

    // Local State
    @State private var selectedFormat: LobbyGameFormat = .strokePlay
    @State private var showLobbyPlayersSheet = false
    @State private var isStarting = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        LobbyCourseSummaryTile(LobbyCourse: LobbyCourse)
                        FormatPickerTile(selected: $selectedFormat)
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Bottom actions
                VStack(spacing: 16) {
                    LiveStatusBar(LobbyPlayers: LobbyPlayers) {
                        showLobbyPlayersSheet = true
                    }
                    
                    PlayCTA(isLoading: isStarting) {
                        withAnimation(.snappy) {
                            isStarting = true
                        }
                        // Simulate start action
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.snappy) { isStarting = false }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {/* dismiss */}) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .accessibilityLabel("Close")
                }
                ToolbarItem(placement: .principal) {
                    Text("Game Lobby").font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { /* show QR / invite */ }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18, weight: .regular))
                    }
                    .accessibilityLabel("Show Lobby QR Code")
                }
            }
            .sheet(isPresented: $showLobbyPlayersSheet) {
                LobbyPlayersSheet(LobbyPlayers: $LobbyPlayers)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Tiles
struct LobbyCourseSummaryTile: View {
    let LobbyCourse: LobbyCourse
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color.green.opacity(0.7), Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "figure.golf").font(.system(size: 24)).foregroundStyle(.white))

                VStack(alignment: .leading, spacing: 6) {
                    Text(LobbyCourse.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Label("Par \(LobbyCourse.par)", systemImage: "flag.fill")
                        Label("\(LobbyCourse.yardage) yds", systemImage: "ruler")
                        Label("\(LobbyCourse.holes) holes", systemImage: "circle.grid.3x3.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let loc = LobbyCourse.location {
                Map(position: .constant(.region(MKCoordinateRegion(center: loc, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))))) {
                    UserAnnotation()
                }
                .frame(height: expanded ? 160 : 80)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    Button(expanded ? "Hide Map" : "Show Map") { withAnimation(.snappy) { expanded.toggle() } }
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.black.opacity(0.05))
        )
    }
}

struct FormatPickerTile: View {
    @Binding var selected: LobbyGameFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Format")
                    .font(.headline)
                Spacer()
            }
            HFlow() {
                ForEach(LobbyGameFormat.allCases) { format in
                    SelectablePill(title: format.rawValue, isSelected: selected == format) {
                        withAnimation(.snappy) { selected = format }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.black.opacity(0.05))
        )
    }
}

// MARK: - Bottom CTA & Live Bar
struct PlayCTA: View {
    var isLoading: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading { ProgressView().tint(.white) }
                Text(isLoading ? "Starting..." : "Play")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(
                Capsule().fill(Color.accentColor.gradient)
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.2))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("playButton")
    }
}

struct LiveStatusBar: View {
    var LobbyPlayers: [LobbyPlayer]
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "figure.golf")
                    .font(.system(size: 18, weight: .semibold))
                Text("\(LobbyPlayers.count) / 8 joined")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                AvatarStack(LobbyPlayers: LobbyPlayers)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.background, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Color.black.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("liveStatusBar")
    }
}

// MARK: - LobbyPlayers Sheet
struct LobbyPlayersSheet: View {
    @Binding var LobbyPlayers: [LobbyPlayer]
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("LobbyPlayers") {
                    ForEach(LobbyPlayers) { LobbyPlayer in
                        HStack(spacing: 12) {
                            Circle().fill(Color.accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay(Text(LobbyPlayer.initials).font(.caption).bold())
                            VStack(alignment: .leading) {
                                Text(LobbyPlayer.name)
                                if LobbyPlayer.isHost {
                                    Text("Host").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if !LobbyPlayer.isHost {
                                Button(role: .destructive) {
                                    withAnimation { LobbyPlayers.removeAll { $0.id == LobbyPlayer.id } }
                                } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                Section("Add LobbyPlayer") {
                    HStack {
                        TextField("Name", text: $newName)
                        Button("Add") {
                            let trimmed = newName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            withAnimation { LobbyPlayers.append(LobbyPlayer(name: trimmed)) }
                            newName = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Manage LobbyPlayers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
        }
    }
}

// MARK: - Components
struct SelectablePill: View {
    let title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct AvatarStack: View {
    var LobbyPlayers: [LobbyPlayer]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(LobbyPlayers.prefix(4).enumerated()), id: \.offset) { _, p in
                Circle().fill(Color.accentColor.opacity(0.2))
                    .frame(width: 26, height: 26)
                    .overlay(Text(p.initials).font(.caption2).bold())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
            if LobbyPlayers.count > 4 {
                Circle().fill(Color(.secondarySystemFill))
                    .frame(width: 26, height: 26)
                    .overlay(Text("+\(LobbyPlayers.count - 4)").font(.caption2))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
        }
    }
}

/// A simple flow layout for wrapping chips/pills
struct FlowLayout<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo.size)
        }
        .frame(minHeight: 0)
    }

    private func generateContent(in size: CGSize) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            content
                .padding(.all, 4)
                .alignmentGuide(.leading, computeValue: { d in
                    if (abs(width - d.width) > size.width) {
                        width = 0
                        height -= d.height + spacing
                    }
                    let result = width
                    if content is EmptyView == false {
                        width -= d.width + spacing
                    }
                    return result
                })
                .alignmentGuide(.top, computeValue: { _ in
                    let result = height
                    if content is EmptyView == false { }
                    return result
                })
        }
    }
}

// MARK: - Preview
struct GameLobbyView_Previews: PreviewProvider {
    static var sampleLobbyCourse = LobbyCourse(
        clubName: "Augusta National",
        LobbyCourseName: "",
        par: 72,
        yardage: 7435,
        holes: 18,
        location: CLLocationCoordinate2D(latitude: 33.5034, longitude: -82.0209)
    )

    static var sampleLobbyPlayers: [LobbyPlayer] = [
        .init(name: "Alex Johnson", isHost: true),
        .init(name: "Sam Patel"),
        .init(name: "Jordan Lee"),
        .init(name: "Taylor Kim"),
        .init(name: "Kai Chen"),
    ]

    static var previews: some View {
        GameLobbyView(LobbyCourse: sampleLobbyCourse, LobbyPlayers: sampleLobbyPlayers)
    }
}
