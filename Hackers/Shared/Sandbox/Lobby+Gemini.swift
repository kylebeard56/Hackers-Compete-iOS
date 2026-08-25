//
//  Lobby+Gemini.swift
//  Hackers
//
//  Created by Kyle Beard on 11/19/25.
//

import SwiftUI

// MARK: - 1. Data Models

/// Defines the possible team colors.
enum GeminiTeamColor: String, CaseIterable, Identifiable {
    case red, blue, green, orange, purple, yellow
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .green
        case .green: return .blue
        case .orange: return .orange
        case .purple: return .purple
        case .yellow: return .yellow
        }
    }

    var capitalizedName: String {
        self.rawValue.capitalized
    }
}

/// Represents a single player in the game.
struct GeminiPlayer: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var handicap: Int = 10
    var team: GeminiTeamColor?
    var teeTimeGroup: Int? // 1, 2, 3, etc.
}

/// Represents a single golf hole.
struct GeminiHole: Identifiable {
    let id = UUID()
    let number: Int
    var par: Int
    var yardage: Int
}

/// Represents a golf course.
struct GeminiCourse: Identifiable {
    let id = UUID()
    let name: String
    let defaultTee: String
    let holes: [GeminiHole]
}

/// Defines the selectable game formats.
enum GeminiGameFormat: String, CaseIterable, Identifiable {
    case strokePlay = "Stroke Play (Individual)"
    case scramble = "Scramble (4-Person)"
    case bestBall = "Best Ball (2-Person Teams)"
    var id: String { rawValue }
}

// MARK: - 2. Mock Data

let mockCourse = GeminiCourse(
    name: "Pinehurst No. 2",
    defaultTee: "Blue (6,800 yds)",
    holes: [
        GeminiHole(number: 1, par: 4, yardage: 440),
        GeminiHole(number: 2, par: 4, yardage: 475),
        GeminiHole(number: 3, par: 3, yardage: 187),
        GeminiHole(number: 4, par: 4, yardage: 480),
        GeminiHole(number: 5, par: 5, yardage: 576),
        GeminiHole(number: 6, par: 4, yardage: 395),
        GeminiHole(number: 7, par: 4, yardage: 420),
        GeminiHole(number: 8, par: 4, yardage: 467),
        GeminiHole(number: 9, par: 3, yardage: 191),
        GeminiHole(number: 10, par: 4, yardage: 407),
        GeminiHole(number: 11, par: 4, yardage: 486),
        GeminiHole(number: 12, par: 4, yardage: 491),
        GeminiHole(number: 13, par: 4, yardage: 382),
        GeminiHole(number: 14, par: 4, yardage: 473),
        GeminiHole(number: 15, par: 3, yardage: 202),
        GeminiHole(number: 16, par: 4, yardage: 450),
        GeminiHole(number: 17, par: 5, yardage: 552),
        GeminiHole(number: 18, par: 4, yardage: 440)
    ]
)

// MARK: - 3. Subviews

struct CourseDetailView: View {
    let course: GeminiCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Course & Tee Selection
            HStack {
                Text("Course: **\(course.name)**")
                Spacer()
                Menu {
                    Text("Blue (6,800 yds)")
                    Text("White (6,400 yds)")
                    Text("Red (5,900 yds)")
                } label: {
                    Label(course.defaultTee, systemImage: "flag.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                }
            }

            // Hole Details Table
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Hole").frame(width: 50)
                    Divider()
                    Text("Par").frame(width: 50)
                    Divider()
                    Text("Yardage").frame(maxWidth: .infinity)
                }
                .font(.caption.bold())
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))

                // Rows
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(course.holes) { hole in
                            VStack(spacing: 0) {
                                HStack {
                                    Text("\(hole.number)").frame(width: 50)
                                    Divider()
                                    Text("\(hole.par)").frame(width: 50)
                                    Divider()
                                    Text("\(hole.yardage)").frame(maxWidth: .infinity)
                                }
                                .padding(.vertical, 4)
                                .background(hole.number % 2 == 0 ? Color.white : Color.gray.opacity(0.05))
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 200) // Constrain height for better layout
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.bottom)
    }
}

struct FormatConfigurationView: View {
    @Binding var selectedFormat: GeminiGameFormat
    @State private var useHandicaps: Bool = true
    @State private var teamSize: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Picker("Game Format", selection: $selectedFormat) {
                ForEach(GeminiGameFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))

            // Format-Specific Configuration
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Apply Handicaps", isOn: $useHandicaps)
                    Spacer()
                }

                if selectedFormat != .strokePlay {
                    Stepper("Team Size: \(teamSize) players", value: $teamSize, in: 2...4)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct PlayerRosterView: View {
    @Binding var players: [GeminiPlayer]
    @State private var newPlayerName: String = ""

    // Computed property to group players by tee time
    var groupedPlayers: [Int: [GeminiPlayer]] {
        Dictionary(grouping: players.filter { $0.teeTimeGroup != nil }, by: { $0.teeTimeGroup! })
    }

    // Players not yet assigned to a group
    var unassignedPlayers: [GeminiPlayer] {
        players.filter { $0.teeTimeGroup == nil }
    }

    // Max group number currently in use
    var maxGroupNumber: Int {
        (groupedPlayers.keys.max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Add New Player
            HStack {
                TextField("New Player Name", text: $newPlayerName)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    if !newPlayerName.isEmpty {
                        players.append(GeminiPlayer(name: newPlayerName))
                        newPlayerName = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            // Unassigned Players
            if !unassignedPlayers.isEmpty {
                GroupBox("Unassigned Roster (\(unassignedPlayers.count))") {
                    PlayerListView(players: $players, filteredPlayers: unassignedPlayers, showGroupControls: true, maxGroup: maxGroupNumber)
                }
            }

            // Tee Time Groups
            VStack(alignment: .leading) {
                Text("Tee Time Groups")
                    .font(.headline)

                if groupedPlayers.isEmpty && unassignedPlayers.isEmpty {
                    Text("Add players to begin grouping.").foregroundColor(.secondary)
                } else if groupedPlayers.isEmpty {
                    Button("Create First Tee Time Group") {
                        // Move the first 4 unassigned players to a new group (Group 1)
                        for i in 0..<min(4, unassignedPlayers.count) {
                            if let index = players.firstIndex(where: { $0.id == unassignedPlayers[i].id }) {
                                players[index].teeTimeGroup = 1
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }

                ForEach(groupedPlayers.keys.sorted(), id: \.self) { groupNumber in
                    GroupBox("Tee Time Group \(groupNumber)") {
                        PlayerListView(players: $players, filteredPlayers: groupedPlayers[groupNumber]!, showGroupControls: false, maxGroup: groupNumber)
                    }
                }
            }
        }
    }
}

struct PlayerListView: View {
    @Binding var players: [GeminiPlayer]
    let filteredPlayers: [GeminiPlayer]
    let showGroupControls: Bool
    let maxGroup: Int // Used to assign new group number

    var body: some View {
        ForEach(filteredPlayers.sorted(by: { $0.name < $1.name })) { player in
            VStack(spacing: 0) {
                HStack {
                    // Player Info
                    VStack(alignment: .leading) {
                        Text(player.name).font(.callout)
                        Text("Handicap: \(player.handicap)").font(.caption).foregroundColor(.secondary)
                    }

                    Spacer()

                    // Team Assignment
                    Menu {
                        ForEach(GeminiTeamColor.allCases) { color in
                            Button {
                                updatePlayerTeam(player: player, team: color)
                            } label: {
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .foregroundColor(color.color)
                                    Text(color.capitalizedName)
                                }
                            }
                        }
                        Button("None", role: .destructive) {
                            updatePlayerTeam(player: player, team: nil)
                        }
                    } label: {
                        HStack {
                            if let team = player.team {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(team.color)
                                Text(team.capitalizedName)
                                    .foregroundColor(.primary)
                            } else {
                                Image(systemName: "flag")
                                Text("Assign Team")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: 120, alignment: .trailing)

                    // Grouping Controls
                    if showGroupControls {
                        Button {
                            assignToNewGroup(player: player)
                        } label: {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(.accentColor)
                        }
                        .padding(.leading, 8)
                    } else if let groupNumber = player.teeTimeGroup {
                        Button {
                            removeFromGroup(player: player)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(.vertical, 8)

                if player.id != filteredPlayers.last?.id {
                    Divider()
                }
            }
        }
    }

    private func updatePlayerTeam(player: GeminiPlayer, team: GeminiTeamColor?) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index].team = team
        }
    }

    private func assignToNewGroup(player: GeminiPlayer) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index].teeTimeGroup = maxGroup + 1
        }
    }

    private func removeFromGroup(player: GeminiPlayer) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index].teeTimeGroup = nil
        }
    }
}

// MARK: - 4. Main View

struct GeminiGameLobbyView: View {
    @State private var selectedFormat: GeminiGameFormat = .strokePlay
    @State private var players: [GeminiPlayer] = [
        GeminiPlayer(name: "Alice Johnson", handicap: 8, team: .red, teeTimeGroup: 1),
        GeminiPlayer(name: "Bob Smith", handicap: 12, team: .red, teeTimeGroup: 1),
        GeminiPlayer(name: "Charlie Brown", handicap: 5, team: .blue, teeTimeGroup: 1),
        GeminiPlayer(name: "Dana Scully", handicap: 15, team: .blue, teeTimeGroup: 2),
        GeminiPlayer(name: "Eve Green", handicap: 18, team: nil, teeTimeGroup: 2),
        GeminiPlayer(name: "Frank White", handicap: 10, team: nil, teeTimeGroup: nil)
    ]

    let course: GeminiCourse = mockCourse

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {

                    // MARK: Course Selection Section
                    GroupBox {
                        CourseDetailView(course: course)
                    } label: {
                        Label("Course Details", systemImage: "map")
                            .font(.title3.bold())
                    }
                    .padding(.horizontal)

                    // MARK: Game Format Section
                    GroupBox {
                        FormatConfigurationView(selectedFormat: $selectedFormat)
                    } label: {
                        Label("Game Format Configuration", systemImage: "figure.golf")
                            .font(.title3.bold())
                    }
                    .padding(.horizontal)

                    // MARK: Player Roster Section
                    GroupBox {
                        PlayerRosterView(players: $players)
                    } label: {
                        Label("Player Roster & Groups", systemImage: "person.3")
                            .font(.title3.bold())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("New Game Setup")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Start Round") {
                        // Action to start the round
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

// Used for SwiftUI Previews in an actual project
 #Preview {
     GeminiGameLobbyView()
 }
