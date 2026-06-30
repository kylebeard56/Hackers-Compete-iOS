//
//  DashboardRoundHistoryView.swift
//  Hackers
//
//  Round history tab content for Dashboard.
//

import SkeletonUI
import SwiftUI

enum RoundHistoryFilter: String, CaseIterable {
    case all = "All"
    case completed = "Completed"
    case upcoming = "Upcoming"
    case inProgress = "In Progress"
    case archived = "Archived"

    func matches(_ round: Round) -> Bool {
        switch self {
        case .all: return true
        case .completed: return round.status == .complete
        case .upcoming: return round.status == .lobby
        case .inProgress: return round.status == .live || round.status == .paused
        case .archived: return round.status == .archived
        }
    }

    var emptyStateTitle: String {
        switch self {
        case .all: return "No rounds found"
        case .completed: return "No completed rounds"
        case .upcoming: return "No upcoming rounds"
        case .inProgress: return "No rounds in progress"
        case .archived: return "No archived rounds"
        }
    }

    var emptyStateSubtitle: String {
        switch self {
        case .all: return "Your rounds will appear here."
        case .completed: return "Completed rounds will appear here."
        case .upcoming: return "Upcoming rounds will appear here."
        case .inProgress: return "Active rounds will appear here."
        case .archived: return "Archived rounds will appear here."
        }
    }
}

private let kMinSkeletonTime: TimeInterval = 1.2
private let kMaxSkeletonTime: TimeInterval = 12

struct DashboardRoundHistoryView: View {
    @EnvironmentObject var appSession: AppSession
    @ObservedObject var viewModel: DashboardViewModel

    let palette: DesignPalette
    let sortedRounds: [Round]
    let playerHistoryEntries: [PlayerHistoryEntry]
    let isLoadingRounds: Bool
    let onRoundTap: (Round) -> Void

    @State private var selectedFilter: RoundHistoryFilter = .all
    @State private var showSkeleton = true
    @State private var skeletonStartTime: Date?
    @State private var roundToDelete: Round?

    private var filteredRounds: [Round] {
        let searchFiltered = viewModel.filteredRounds(from: sortedRounds, playerHistoryEntries: playerHistoryEntries)
        return searchFiltered.filter { selectedFilter.matches($0) }
    }

    private var isSearchActive: Bool {
        viewModel.roundsSearchText.trimmingCharacters(in: .whitespaces).isPopulated
    }

    private var filterMenuData: (courses: [(name: String, count: Int)], players: [(name: String, count: Int)], formats: [(name: String, count: Int)]) {
        var courseCounts: [String: Int] = [:]
        var playerCounts: [String: Int] = [:]
        var formatCounts: [String: Int] = [:]

        for round in sortedRounds {
            if let course = round.configuration.courses.first {
                let name = course.courseInfo.name
                courseCounts[name, default: 0] += 1
            }
            var playersInRound = Set<String>()
            for completed in round.completedPlayers {
                if let name = completed.playerDisplayName, !name.isEmpty {
                    playersInRound.insert(name)
                }
            }
            for entry in playerHistoryEntries {
                if entry.rounds.contains(where: { $0.roundID == round.id }) {
                    let name = entry.name.fullName
                    if !name.isEmpty {
                        playersInRound.insert(name)
                    }
                }
            }
            for name in playersInRound {
                playerCounts[name, default: 0] += 1
            }
            let formatName = round.configuration.formatSummary?.name ?? round.configuration.primaryFormat.type.displayName
            formatCounts[formatName, default: 0] += 1
        }

        let courses = courseCounts.map { (name: $0.key, count: $0.value) }.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        let players = playerCounts.map { (name: $0.key, count: $0.value) }.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            let aLast = String(a.name.split(separator: " ").last ?? "")
            let bLast = String(b.name.split(separator: " ").last ?? "")
            return aLast.localizedCaseInsensitiveCompare(bLast) == .orderedAscending
        }
        let formats = formatCounts.map { (name: $0.key, count: $0.value) }.sorted { a, b in
            if a.count != b.count { return a.count > b.count }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        return (courses, players, formats)
    }

    private var roundsByMonth: [(String, [Round])] {
        let calendar = Calendar.current
        struct MonthKey: Hashable {
            let year: Int
            let month: Int
        }
        let grouped = Dictionary(grouping: filteredRounds) { round -> MonthKey in
            let date = Date(timeIntervalSince1970: round.displayDate.unix)
            let components = calendar.dateComponents([.year, .month], from: date)
            return MonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return grouped
            .map { key, rounds in
                let date = Date(timeIntervalSince1970: rounds.max(by: { $0.displayDate.unix < $1.displayDate.unix })!.displayDate.unix)
                let header = formatter.string(from: date)
                let sorted = rounds.sorted { $0.displayDate.unix > $1.displayDate.unix }
                return (header, sorted)
            }
            .sorted { a, b in
                let aDate = a.1.first?.displayDate.unix ?? 0
                let bDate = b.1.first?.displayDate.unix ?? 0
                return aDate > bDate
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Round history")
                .fontStyle(kFontName, size: 24, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .alignLeading()

            HStack(spacing: 12) {
                SearchBar(
                    placeholder: "Search rounds...",
                    initialValue: viewModel.roundsSearchText,
                    theme: .glass,
                    onDebounce: { text in
                        viewModel.roundsSearchText = text
                    }
                )
                .frame(maxWidth: .infinity)

                if !isSearchActive, filterMenuData.courses.isPopulated || filterMenuData.players.isPopulated || filterMenuData.formats.isPopulated {
                    filterMenuButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)

            filterChips
                .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                Group {
                    if showSkeleton {
                        roundHistorySkeleton
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    } else if roundsByMonth.isEmpty {
                        Group {
                            if isSearchActive {
                                EmptyStateView(
                                    imageName: EmptyStatePreset.roundHistory.imageName,
                                    title: "No rounds found",
                                    subtitle: "Try searching by player name, course name, or game format.",
                                    background: .init(
                                        cornerRadius: 20,
                                        fill: palette.backgroundColor.opacity(0.6),
                                        padding: 16
                                    )
                                )
                                .padding(.horizontal, 32)
                            } else {
                                EmptyStateView(
                                    imageName: EmptyStatePreset.roundHistory.imageName,
                                    title: selectedFilter.emptyStateTitle,
                                    subtitle: selectedFilter.emptyStateSubtitle,
                                    background: .init(
                                        cornerRadius: 20,
                                        fill: palette.backgroundColor.opacity(0.6),
                                        padding: 16
                                    )
                                )
                                .padding(.horizontal, 32)
                            }
                        }
                        .frame(minHeight: 400)
                        .padding(.top, 40)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(roundsByMonth, id: \.0) { header, rounds in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(header)
                                        .fontStyle(kFontName, size: 15, weight: .semibold)
                                        .foregroundStyle(palette.foregroundColor)
                                        .padding(.horizontal, 4)

                                    ForEach(rounds, id: \.self) { round in
                                        Button {
                                            Haptics.fire(.light)
                                            onRoundTap(round)
                                        } label: {
                                            DashboardRoundTile(
                                                round: round,
                                                palette: palette,
                                                showDate: true,
                                                showWeekdayFormat: true,
                                                currentPlayerID: viewModel.currentPlayerID
                                            )
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(16)
                                        }
                                        .buttonStyle(.plain)
                                        .glassCardEffect(cornerRadius: 14, forceMaterial: true, tint: palette.cardColor)
                                        .contextMenu {
                                            Button {
                                                Haptics.fire(.light)
                                                onRoundTap(round)
                                            } label: {
                                                Label("Enter round", systemImage: "figure.golf")
                                            }
                                            if round.createdBy == viewModel.currentUserID, round.status != .archived {
                                                Button {
                                                    Haptics.fire(.light)
                                                    Task { await appSession.archiveRound(round) }
                                                } label: {
                                                    Label("Archive round", systemImage: "archivebox")
                                                }
                                            }
                                            Divider()
                                            if round.createdBy == viewModel.currentUserID {
                                                Button(role: .destructive) {
                                                    Haptics.fire(.light)
                                                    roundToDelete = round
                                                } label: {
                                                    Label("Delete round", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 140)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            if isLoadingRounds {
                skeletonStartTime = Date()
                showSkeleton = true
            }
            runSkeletonTimingIfNeeded()
        }
        .onChange(of: isLoadingRounds) { _, isNowLoading in
            if isNowLoading {
                skeletonStartTime = Date()
                showSkeleton = true
            } else {
                runSkeletonTimingIfNeeded()
            }
        }
        .confirmationDialog("Delete round?", isPresented: Binding(
            get: { roundToDelete != nil },
            set: { if !$0 { roundToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Cancel", role: .cancel) { roundToDelete = nil }
            Button("Delete", role: .destructive) {
                guard let round = roundToDelete else { return }
                roundToDelete = nil
                Task { await appSession.deleteRound(round) }
            }
        } message: {
            Text("This will permanently delete the round and cannot be undone.")
        }
    }

    private func runSkeletonTimingIfNeeded() {
        guard !isLoadingRounds else { return }
        let start = skeletonStartTime ?? Date()
        Task {
            while true {
                let elapsed = Date().timeIntervalSince(start)
                let metMinimum = elapsed >= kMinSkeletonTime
                if metMinimum { break }
                if elapsed >= kMaxSkeletonTime { break }
                try? await Task.sleep(for: .milliseconds(50))
            }
            await MainActor.run {
                skeletonStartTime = nil
                showSkeleton = false
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RoundHistoryFilter.allCases, id: \.self) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        Haptics.fire(.light)
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .lineLimit(1)
                            .fontStyle(kFontName, size: 14, weight: .semibold)
                            .foregroundStyle(isSelected ? palette.foregroundColor : Color.neutral)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .glassCardEffect(
                                shape: .capsule,
                                tint: isSelected ? palette.whiteGlassButtonColor : nil
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var filterMenuButton: some View {
        let data = filterMenuData
        Menu {
            if !data.courses.isEmpty {
                Menu("Course") {
                    ForEach(data.courses, id: \.name) { item in
                        filterMenuItem(name: item.name, count: item.count)
                    }
                }
            }
            if !data.players.isEmpty {
                Menu("Players") {
                    ForEach(data.players, id: \.name) { item in
                        filterMenuItem(name: item.name, count: item.count)
                    }
                }
            }
            if !data.formats.isEmpty {
                Menu("Formats") {
                    ForEach(data.formats, id: \.name) { item in
                        filterMenuItem(name: item.name, count: item.count)
                    }
                }
            }
        } label: {
            Icon(name: "f0b0", size: 20, weight: .regular)
                .foregroundStyle(palette.foregroundColor)
                .frame(width: 44, height: 44)
                .glassCardEffect(shape: .capsule, tint: palette.whiteGlassButtonColor)
        }
    }

    private func filterMenuItem(name: String, count: Int) -> some View {
        Button {
            Haptics.fire(.light)
            viewModel.roundsSearchText = name
        } label: {
            Text(name)
            Text("\(count) result\(count.pluralized)")
                .fontStyle(kFontName, size: 12, weight: .regular)
                .foregroundStyle(Color.neutral)
        }
    }

    private var roundHistorySkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: Color.charcoal.opacity(0.5),
                            background: Color.charcoal.opacity(0.2)
                        ),
                        shape: .rounded(.radius(6)),
                        lines: 1,
                        scales: [1: 0.4]
                    )
                    .frame(width: 100, height: 15)
                    .padding(.horizontal, 4)

                ForEach(0..<3, id: \.self) { _ in
                    roundHistoryTileSkeleton
                }
            }
        }
    }

    private var roundHistoryTileSkeleton: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: Color.accentGreen.opacity(0.4),
                            background: Color.accentGreen.opacity(0.2)
                        ),
                        shape: .rounded(.radius(8)),
                        lines: 1,
                        scales: [1: 0.6]
                    )
                    .frame(width: 140, height: 16)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.clear)
                    .skeleton(
                        with: true,
                        animation: .linear(duration: 2),
                        appearance: .solid(
                            color: Color.accentGreen.opacity(0.4),
                            background: Color.accentGreen.opacity(0.2)
                        ),
                        shape: .rounded(.radius(8)),
                        lines: 1,
                        scales: [1: 0.4]
                    )
                    .frame(width: 80, height: 12)
            }
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .skeleton(
                    with: true,
                    animation: .linear(duration: 2),
                    appearance: .solid(
                        color: Color.accentGreen.opacity(0.4),
                        background: Color.accentGreen.opacity(0.2)
                    ),
                    shape: .rounded(.radius(8)),
                    lines: 1,
                    scales: [1: 0.6]
                )
                .frame(width: 60, height: 24)
        }
        .padding(16)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppSession.forPreview())
        .environmentObject(RoundSession())
}
